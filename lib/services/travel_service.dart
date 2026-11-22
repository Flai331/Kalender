import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_event.dart';
import '../models/travel_times.dart';

/// An- und Abfahrtszeiten mit Vererbung.
///
/// Eingestellt werden kann auf drei Ebenen; die genauere gewinnt, und zwar je
/// Seite getrennt (ein Termin kann eine eigene Anfahrt haben und die Abfahrt
/// weiter vom Kalender beziehen):
///
///   1. der einzelne Termin
///   2. die Serie — bei importierten Terminen alle Vorkommen mit derselben UID
///   3. der Kalender — der eigene oder eine importierte Quelle
///   4. sonst keine Zeit
///
/// Wo die Werte liegen, haengt an der Art des Termins:
///
/// * Eigene Termine tragen ihre Zeit selbst (`travelBeforeOverride` am
///   CalendarEvent). Sie gehoert zum Termin und wird mitgespeichert.
/// * Importierte Termine koennen das nicht: sie werden bei jedem Abruf neu
///   aus dem Abonnement gelesen, ein Schreiben daran waere beim naechsten
///   Abruf weg. Ihre Zeiten liegen deshalb hier, unter der Termin-Kennung
///   bzw. der Serien-UID. So bleibt der Termin am Abonnement haengen und
///   folgt weiter Verschiebungen aus dem fremden Kalender.
///
/// Die Vorgaben liegen in den Einstellungen (SharedPreferences), wie die
/// ICS-Quellen selbst, und werden einmal in den Speicher geladen — damit
/// [resolve] ohne await auskommt und in `build` aufgerufen werden kann.
class TravelService {
  /// Kennung des eigenen Kalenders in den Kalender-Vorgaben.
  static const String ownCalendarId = 'app';

  static const String _calendarsKey = 'travel_calendar_defaults';
  static const String _seriesKey = 'travel_series_overrides';
  static const String _eventsKey = 'travel_event_overrides';

  static Map<String, TravelTimes> _calendars = {};
  static Map<String, TravelTimes> _series = {};
  static Map<String, TravelTimes> _events = {};
  static bool _loaded = false;

  /// Zaehlt bei jeder Aenderung hoch. Die Wochenansicht hoert darauf und
  /// zeichnet neu — sonst stuenden die alten Zeiten bis zum naechsten Laden.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool get isLoaded => _loaded;

  // ── Laden und Speichern ──────────────────────────────────────────────────

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _calendars = _decode(prefs.getString(_calendarsKey));
    _series = _decode(prefs.getString(_seriesKey));
    _events = _decode(prefs.getString(_eventsKey));
    _loaded = true;
    revision.value++;
  }

  /// Nur fuer Tests: setzt den Speicher auf einen bekannten Stand.
  @visibleForTesting
  static void resetForTesting() {
    _calendars = {};
    _series = {};
    _events = {};
    _loaded = false;
  }

  static Map<String, TravelTimes> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, TravelTimes>{};
      decoded.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          out['$key'] = TravelTimes.fromJson(value);
        }
      });
      return out;
    } catch (_) {
      // Unlesbare Einstellung darf die App nicht aufhalten.
      return {};
    }
  }

  static Future<void> _store(String key, Map<String, TravelTimes> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        key, jsonEncode(map.map((k, v) => MapEntry(k, v.toJson()))));
    revision.value++;
  }

  /// Leere Eintraege nicht behalten — sonst waechst die Einstellung mit jedem
  /// Zuruecksetzen auf „Vorgabe" weiter.
  static void _put(Map<String, TravelTimes> map, String key, TravelTimes? t) {
    if (t == null || t.isEmpty) {
      map.remove(key);
    } else {
      map[key] = t;
    }
  }

  // ── Kalender-Vorgaben ────────────────────────────────────────────────────

  static TravelTimes calendarTimes(String calendarId) =>
      _calendars[calendarId] ?? TravelTimes.none;

  static Future<void> setCalendarTimes(
      String calendarId, TravelTimes? times) async {
    _put(_calendars, calendarId, times);
    await _store(_calendarsKey, _calendars);
  }

  // ── Serien (importierte Termine) ─────────────────────────────────────────

  static TravelTimes seriesTimes(String seriesKey) =>
      _series[seriesKey] ?? TravelTimes.none;

  static Future<void> setSeriesTimes(
      String seriesKey, TravelTimes? times) async {
    _put(_series, seriesKey, times);
    await _store(_seriesKey, _series);
  }

  // ── Einzelne importierte Termine ─────────────────────────────────────────

  static TravelTimes eventTimes(String eventId) =>
      _events[eventId] ?? TravelTimes.none;

  static Future<void> setEventTimes(String eventId, TravelTimes? times) async {
    _put(_events, eventId, times);
    await _store(_eventsKey, _events);
  }

  // ── Zuordnung ────────────────────────────────────────────────────────────

  /// Der Kalender, zu dem ein Termin gehoert: die importierte Quelle, sonst
  /// der eigene Kalender.
  static String calendarIdOf(CalendarEvent event) =>
      event.icsSourceId ?? ownCalendarId;

  /// Der Serien-Schluessel eines importierten Termins.
  ///
  /// Alle Vorkommen einer Serie teilen im Abonnement dieselbe UID — die steht
  /// bei ICS-Terminen in `outlookEventId`. Eigene Termine liegen als ein
  /// einzelner Datensatz vor und sind damit selbst ihre Serie; fuer sie gibt
  /// es hier keinen Schluessel.
  static String? seriesKeyOf(CalendarEvent event) {
    if (event.source != 'ics') return null;
    final uid = event.outlookEventId;
    if (uid == null || uid.isEmpty) return null;
    return 'ics:$uid';
  }

  /// Kann dieser Termin seine Zeiten selbst tragen? Eigene ja, importierte
  /// nicht (siehe Klassenkommentar).
  static bool storesOwnTimes(CalendarEvent event) => event.source != 'ics';

  // ── Auflösen ─────────────────────────────────────────────────────────────

  static int _first(List<int?> chain) {
    for (final value in chain) {
      if (value != null) return value < 0 ? 0 : value;
    }
    return 0;
  }

  /// Die eingestellten Zeiten dieses Termins — ohne das Geerbte.
  /// Leer heisst: der Termin erbt vollstaendig.
  static TravelTimes ownTimesOf(CalendarEvent event) {
    if (storesOwnTimes(event)) {
      return TravelTimes(
          before: event.travelBeforeOverride, after: event.travelAfterOverride);
    }
    return eventTimes(event.id);
  }

  /// Was gelten wuerde, wenn der Termin selbst nichts eingestellt hat.
  static TravelTimes inheritedFor(CalendarEvent event) {
    final seriesKey = seriesKeyOf(event);
    final series = seriesKey == null ? TravelTimes.none : seriesTimes(seriesKey);
    final cal = calendarTimes(calendarIdOf(event));
    return TravelTimes(
      before: series.before ?? cal.before,
      after: series.after ?? cal.after,
    );
  }

  /// Setzt die geltenden Zeiten in den Termin ein.
  ///
  /// Das Ergebnis ist zur Anzeige und zum Rechnen gedacht; die aufgeloesten
  /// Werte werden absichtlich nicht gespeichert (siehe CalendarEvent.toJson),
  /// sonst fror der erste Abruf die damalige Vorgabe am Termin ein.
  static CalendarEvent resolve(CalendarEvent event) {
    // Zu einem Termin, der nur zur Kenntnis dasteht, faehrt man nicht hin.
    if (event.infoOnly) {
      return event.copyWith(travelMinutesBefore: 0, travelMinutesAfter: 0);
    }
    final own = ownTimesOf(event);
    final inherited = inheritedFor(event);
    return event.copyWith(
      travelMinutesBefore: _first([own.before, inherited.before]),
      travelMinutesAfter: _first([own.after, inherited.after]),
    );
  }

  static List<CalendarEvent> resolveAll(Iterable<CalendarEvent> events) =>
      events.map(resolve).toList();
}
