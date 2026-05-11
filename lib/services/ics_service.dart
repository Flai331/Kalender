import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calendar_event.dart';

class IcsService {
  static const String _urlKey = 'ics_calendar_url';

  static Future<String?> getSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_urlKey);
  }

  static Future<void> saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url);
  }

  static Future<void> clearUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
  }

  static bool get isConfigured => true; // immer verfügbar

  /// Alle Events aus dem ICS-Feed laden
  static Future<List<CalendarEvent>> fetchEvents() async {
    final url = await getSavedUrl();
    if (url == null || url.isEmpty) return [];
    try {
      final httpUrl = url.replaceFirst('webcal://', 'https://');
      final response = await http
          .get(Uri.parse(httpUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      return _parseIcs(response.body);
    } catch (_) {
      return [];
    }
  }

  static List<CalendarEvent> _parseIcs(String raw) {
    final events = <CalendarEvent>[];
    final lines = _unfold(raw);

    bool inEvent = false;
    final props = <String, String>{};

    for (final line in lines) {
      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        props.clear();
      } else if (line == 'END:VEVENT') {
        inEvent = false;
        final ev = _build(props);
        if (ev != null) events.add(ev);
      } else if (inEvent) {
        final colon = line.indexOf(':');
        if (colon > 0) {
          // Key kann Parameter haben: DTSTART;TZID=Europe/Berlin:20240101T...
          final rawKey = line.substring(0, colon);
          final key = rawKey.split(';').first;
          final value = line.substring(colon + 1);
          props[key] = value;
        }
      }
    }
    return events;
  }

  static List<String> _unfold(String content) {
    // RFC 5545: Folded lines beginnen mit Leerzeichen oder Tab
    final unfolded = content
        .replaceAll('\r\n ', '')
        .replaceAll('\r\n\t', '')
        .replaceAll('\n ', '')
        .replaceAll('\n\t', '');
    return unfolded
        .split(RegExp(r'\r?\n'))
        .where((l) => l.isNotEmpty)
        .toList();
  }

  static CalendarEvent? _build(Map<String, String> p) {
    try {
      final uid = p['UID'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      final summary = _decode(p['SUMMARY'] ?? 'Kein Titel');
      final dtstart = p['DTSTART'];
      final dtend = p['DTEND'];

      if (dtstart == null) return null;

      final start = _parseDateTime(dtstart);
      if (start == null) return null;

      final end = dtend != null
          ? _parseDateTime(dtend) ?? start.add(const Duration(hours: 1))
          : start.add(const Duration(hours: 1));

      final isAllDay = dtstart.length == 8;

      return CalendarEvent(
        id: 'ics_${uid.hashCode.abs()}',
        title: summary,
        description: _decode(p['DESCRIPTION'] ?? ''),
        startTime: start,
        endTime: end,
        isAllDay: isAllDay,
        source: 'outlook',
        outlookEventId: uid,
        category: EventCategory.work,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDateTime(String value) {
    try {
      // Reines Datum: 20240101
      if (value.length == 8) {
        return DateTime(
          int.parse(value.substring(0, 4)),
          int.parse(value.substring(4, 6)),
          int.parse(value.substring(6, 8)),
        );
      }
      // DateTime: 20240101T120000Z  oder  20240101T120000
      if (value.length >= 15) {
        final y = int.parse(value.substring(0, 4));
        final mo = int.parse(value.substring(4, 6));
        final d = int.parse(value.substring(6, 8));
        final h = int.parse(value.substring(9, 11));
        final mi = int.parse(value.substring(11, 13));
        final s = int.parse(value.substring(13, 15));
        if (value.endsWith('Z')) {
          return DateTime.utc(y, mo, d, h, mi, s).toLocal();
        }
        return DateTime(y, mo, d, h, mi, s);
      }
    } catch (_) {}
    return null;
  }

  static String _decode(String value) => value
      .replaceAll('\\n', '\n')
      .replaceAll('\\,', ',')
      .replaceAll('\\;', ';')
      .replaceAll('\\\\', '\\');
}
