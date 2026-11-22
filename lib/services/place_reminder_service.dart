import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_event.dart';
import 'feedback_service.dart';
import 'local_service.dart';
import 'reminder_service.dart';

/// Meldet sich, bevor ein Termin mit Ortsgruppe ansteht, und sagt dann,
/// wohin man kann.
///
/// Der Vorschlag wird bewusst **nicht** beim Anlegen des Termins gemacht:
/// ob das Studio um 19 Uhr noch offen hat und welches gerade das naechste
/// ist, weiss man erst, wenn es so weit ist. Beim Anlegen waehlt man nur
/// die Gruppe.
class PlaceReminderService {
  /// Wie lange vorher gemeldet wird.
  static const String prefLead = 'place_suggest_lead_minutes';
  static const int defaultLeadMinutes = 90;

  /// Die zuletzt geplanten Benachrichtigungen, damit geloeschte Termine
  /// ihre Meldung wieder verlieren.
  static const String _prefGeplant = 'place_suggest_scheduled';

  /// Weiter als das voraus zu planen lohnt nicht: die App laeuft oft genug.
  static const Duration _horizont = Duration(days: 3);

  static Future<int> leadMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefLead) ?? defaultLeadMinutes;
  }

  static Future<void> setLeadMinutes(int minuten) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefLead, minuten);
    await scheduleAll();
  }

  /// Die Kennung der Benachrichtigung zu einem Termin.
  ///
  /// Aus der Termin-Kennung abgeleitet und auf 30 Bit gestutzt: Android
  /// nimmt nur 32-Bit-Zahlen, und negativ soll sie auch nicht sein.
  static int notificationId(String eventId) =>
      'ortsvorschlag:$eventId'.hashCode & 0x3FFFFFFF;

  /// Welche Termine bekommen eine Meldung, und wann?
  ///
  /// Rein gerechnet, damit es ohne Datenbank und ohne Android pruefbar ist.
  static List<({CalendarEvent event, DateTime at})> plan({
    required List<CalendarEvent> events,
    required DateTime now,
    required int leadMinutes,
  }) {
    final grenze = now.add(_horizont);
    final out = <({CalendarEvent event, DateTime at})>[];
    for (final e in events) {
      final gruppe = e.placeGroup?.trim() ?? '';
      if (gruppe.isEmpty) continue;
      if (e.isAllDay) continue;
      // Der Dienstplan eines anderen Menschen braucht keinen Vorschlag,
      // wohin **ich** gehen soll.
      if (e.infoOnly) continue;
      if (e.status == EventStatus.done) continue;
      if (!e.startTime.isAfter(now)) continue;
      if (e.startTime.isAfter(grenze)) continue;

      // Ueber die Minuten statt mit Duration: an der Nacht der Zeitumstellung
      // haette eine abgezogene Dauer die falsche Uhrzeit.
      final s = e.startTime;
      var at = DateTime(s.year, s.month, s.day, s.hour, s.minute - leadMinutes);
      // Ein Termin, der schon innerhalb der Vorlaufzeit liegt, soll nicht
      // stumm bleiben — dann eben gleich.
      if (!at.isAfter(now)) {
        at = now.add(const Duration(minutes: 1));
        if (!at.isBefore(e.startTime)) continue;
      }
      out.add((event: e, at: at));
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  /// Der Text der Meldung. Welcher Ort es wird, steht hier bewusst nicht —
  /// das entscheidet sich erst beim Antippen, mit dem Standort von dann.
  static String body(CalendarEvent e, int leadMinutes) {
    final gruppe = e.placeGroup ?? 'Ort';
    final zeit = '${e.startTime.hour.toString().padLeft(2, '0')}:'
        '${e.startTime.minute.toString().padLeft(2, '0')}';
    return 'Um $zeit. Tippen zeigt, welches $gruppe offen hat.';
  }

  /// Plant alle faelligen Meldungen neu. Wirft nie.
  static Future<void> scheduleAll() async {
    try {
      final events = await LocalService.getAllEvents();
      final lead = await leadMinutes();
      final termine = plan(
        events: events,
        now: DateTime.now(),
        leadMinutes: lead,
      );

      final prefs = await SharedPreferences.getInstance();
      final alt = (prefs.getStringList(_prefGeplant) ?? [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

      final neu = <int>{};
      for (final t in termine) {
        final id = notificationId(t.event.id);
        neu.add(id);
        await ReminderService.scheduleAt(
          id: id,
          title: t.event.title,
          body: body(t.event, lead),
          scheduledAt: t.at,
          payload: payloadFor(t.event.id),
          channelId: 'ortsvorschlag',
          channelName: 'Ortsvorschläge',
          channelDescription:
              'Meldet sich vor einem Termin mit Ortsgruppe und sagt, '
              'wohin man kann.',
        );
      }

      // Was weg ist, soll nicht mehr klingeln.
      for (final id in alt.difference(neu)) {
        await ReminderService.cancel(id);
      }
      await prefs.setStringList(
          _prefGeplant, neu.map((i) => i.toString()).toList());
    } catch (e) {
      FeedbackService.log('Ortsvorschläge nicht planbar: $e');
    }
  }

  /// Nimmt die Meldung zu einem Termin zurueck — beim Loeschen oder wenn
  /// die Gruppe entfernt wurde.
  static Future<void> cancelFor(String eventId) async {
    try {
      await ReminderService.cancel(notificationId(eventId));
    } catch (_) {
      // Eine nicht geplante Meldung abzusagen ist kein Fehler.
    }
  }

  // ── Nutzlast ────────────────────────────────────────────────────────────

  static const String _prefix = 'ortsvorschlag';

  static String payloadFor(String eventId) =>
      jsonEncode({'typ': _prefix, 'eventId': eventId});

  /// Liest die Termin-Kennung aus der Nutzlast einer Benachrichtigung.
  /// Null, wenn die Meldung von woanders kommt.
  static String? eventIdFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final roh = jsonDecode(payload);
      if (roh is! Map) return null;
      if (roh['typ'] != _prefix) return null;
      final id = roh['eventId'];
      return id is String && id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }
}
