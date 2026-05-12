import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/calendar_event.dart';
import '../models/ics_source.dart';

const _uuid = Uuid();

class IcsService {
  static const String _sourcesKey = 'ics_sources';
  static const String _outlookAllowTodoDropKey = 'outlook_allow_todo_drop';

  static Future<bool> getOutlookAllowTodoDrop() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_outlookAllowTodoDropKey) ?? false;
  }

  static Future<void> setOutlookAllowTodoDrop(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_outlookAllowTodoDropKey, value);
  }
  // Legacy-Key für Migration
  static const String _legacyUrlKey = 'ics_calendar_url';

  // ── Quellen verwalten ──────────────────────────────────────

  static Future<List<IcsSource>> getSources() async {
    final prefs = await SharedPreferences.getInstance();

    // Migration: alten Single-URL-Eintrag übernehmen
    if (!prefs.containsKey(_sourcesKey)) {
      final legacy = prefs.getString(_legacyUrlKey);
      if (legacy != null && legacy.isNotEmpty) {
        final migrated = [
          IcsSource(id: _uuid.v4(), name: 'Outlook', url: legacy)
        ];
        await prefs.setString(_sourcesKey, IcsSource.listToJson(migrated));
        await prefs.remove(_legacyUrlKey);
        return migrated;
      }
      return [];
    }

    final raw = prefs.getString(_sourcesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return IcsSource.listFromJson(raw);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSources(List<IcsSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sourcesKey, IcsSource.listToJson(sources));
  }

  static Future<IcsSource> addUrl(String url, String name) async {
    final sources = await getSources();
    final source = IcsSource(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Kalender ${sources.length + 1}' : name.trim(),
      url: normalizeUrl(url),
      isFile: false,
    );
    sources.add(source);
    await saveSources(sources);
    return source;
  }

  static Future<IcsSource> addFile(String filePath, String name) async {
    final sources = await getSources();
    final source = IcsSource(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Kalender ${sources.length + 1}' : name.trim(),
      url: filePath,
      isFile: true,
    );
    sources.add(source);
    await saveSources(sources);
    return source;
  }

  static Future<void> removeSource(String id) async {
    final sources = await getSources();
    sources.removeWhere((s) => s.id == id);
    await saveSources(sources);
  }

  // ── URL normalisieren ──────────────────────────────────────

  static String normalizeUrl(String url) {
    var u = url.trim();
    u = u.replaceFirst('webcal://', 'https://');
    if (u.contains('outlook.live.com') && u.endsWith('index.html')) {
      u = '${u.substring(0, u.length - 'index.html'.length)}calendar.ics';
    }
    if (u.contains('outlook.live.com') && u.endsWith('index.htm')) {
      u = '${u.substring(0, u.length - 'index.htm'.length)}calendar.ics';
    }
    return u;
  }

  // ── Events laden ───────────────────────────────────────────

  static Future<List<CalendarEvent>> fetchEvents() async {
    final sources = await getSources();
    if (sources.isEmpty) return [];

    final results = await Future.wait(
      sources.map((s) => _fetchSource(s)),
    );
    return results.expand((e) => e).toList();
  }

  static Future<List<CalendarEvent>> _fetchSource(IcsSource source) async {
    try {
      final String raw;
      if (source.isFile) {
        raw = await File(source.url).readAsString();
      } else {
        final response = await http
            .get(Uri.parse(source.url))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) return [];
        raw = response.body;
      }
      return _parseIcs(raw, calendarName: source.name, calendarColor: source.color, sourceId: source.id);
    } catch (_) {
      return [];
    }
  }

  // ── ICS parsen ─────────────────────────────────────────────

  static List<CalendarEvent> _parseIcs(String raw,
      {String calendarName = '', int? calendarColor, String? sourceId}) {
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
        final ev = _build(props, calendarName: calendarName, calendarColor: calendarColor, sourceId: sourceId);
        if (ev != null) events.add(ev);
      } else if (inEvent) {
        final colon = line.indexOf(':');
        if (colon > 0) {
          final rawKey = line.substring(0, colon);
          final key = rawKey.split(';').first;
          final value = line.substring(colon + 1);
          props[key] = value;
          if (rawKey.length > key.length) {
            props['${key}_PARAMS'] = rawKey.substring(key.length + 1).toUpperCase();
          }
        }
      }
    }
    return events;
  }

  static List<String> _unfold(String content) {
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

  static CalendarEvent? _build(Map<String, String> p,
      {String calendarName = '', int? calendarColor, String? sourceId}) {
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

      final dtStartParams = p['DTSTART_PARAMS'] ?? '';
      final rawEnd = p['DTEND'] ?? '';
      // T000000 at position 9 covers both local (T000000) and UTC (T000000Z)
      final startsAtMidnight = dtstart.length >= 15 && dtstart.substring(9, 15) == '000000';
      final endsAtMidnight = rawEnd.isEmpty || rawEnd.length == 8 ||
          (rawEnd.length >= 15 && rawEnd.substring(9, 15) == '000000');
      final isAllDay = dtstart.length == 8 ||
          dtStartParams.contains('VALUE=DATE') ||
          (startsAtMidnight && endsAtMidnight);

      return CalendarEvent(
        id: 'ics_${uid.hashCode.abs()}',
        title: summary,
        description: _decode(p['DESCRIPTION'] ?? ''),
        startTime: start,
        endTime: end,
        isAllDay: isAllDay,
        source: 'ics',
        outlookEventId: uid,
        category: EventCategory.work,
        calendarColor: calendarColor,
        icsSourceId: sourceId,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDateTime(String value) {
    try {
      if (value.length == 8) {
        return DateTime(
          int.parse(value.substring(0, 4)),
          int.parse(value.substring(4, 6)),
          int.parse(value.substring(6, 8)),
        );
      }
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
