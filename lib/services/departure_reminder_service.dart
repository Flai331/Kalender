import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_event.dart';
import '../models/reminder_urgency.dart';
import '../models/todo.dart';
import 'feedback_service.dart';
import 'ics_service.dart';
import 'local_service.dart';
import 'reminder_service.dart';
import 'travel_service.dart';

/// Ein geplanter Hinweis: wann gemeldet wird, und worauf.
typedef Abfahrt = ({
  /// Kennung des Termins oder To-dos — daraus wird die Kennung der Meldung.
  String id,
  String titel,

  /// Wann man los muss: Beginn minus Anfahrt.
  DateTime los,
  DateTime start,
  int fahrt,

  /// Wann gemeldet wird: [los] minus Vorlauf.
  DateTime at,
});

/// Meldet sich, bevor man losfahren muss.
///
/// Nicht vor dem **Termin** — vor der **Abfahrt**. Wer um 8:00 anfangen muss
/// und 20 Minuten faehrt, will um 7:35 Bescheid bekommen und nicht um 7:55.
/// Termine ohne Anfahrt bekommen darum auch keine Meldung: da gibt es nichts
/// loszufahren.
class DepartureReminderService {
  /// Ob ueberhaupt gemeldet wird.
  static const String prefAn = 'departure_reminder_on';

  /// Wie lange vor der Abfahrt.
  static const String prefLead = 'departure_lead_minutes';
  static const int defaultLeadMinutes = 5;

  /// Wie eindringlich.
  static const String prefUrgency = 'departure_urgency';
  static const ReminderUrgency defaultUrgency = ReminderUrgency.dringend;

  /// Die zuletzt geplanten Meldungen, damit geloeschte und verschobene
  /// Termine ihre alte Meldung wieder verlieren.
  static const String _prefGeplant = 'departure_scheduled';

  /// Wie weit voraus geplant wird.
  ///
  /// Laenger als beim Ortsvorschlag (3 Tage): diese Meldung ist der
  /// Unterschied zwischen puenktlich und zu spaet. Wer uebers Wochenende
  /// nicht in die App schaut, soll am Montag trotzdem gewarnt werden.
  static const Duration _horizont = Duration(days: 7);

  // ── Einstellungen ────────────────────────────────────────────────────────

  static Future<bool> istAn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefAn) ?? true;
  }

  /// Die drei Setzer schreiben die Einstellung und stellen die Meldungen
  /// **im Hintergrund** neu. Bewusst ohne `await`: das Neustellen holt unter
  /// Umstaenden die Abo-Kalender aus dem Netz, und niemand soll in den
  /// Einstellungen 15 Sekunden auf einen Schalter warten. `scheduleAll`
  /// wirft nicht und laeuft immer nur einmal gleichzeitig.
  static Future<void> setAn(bool an) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefAn, an);
    unawaited(scheduleAll());
  }

  static Future<int> leadMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefLead) ?? defaultLeadMinutes;
  }

  static Future<void> setLeadMinutes(int minuten) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefLead, minuten);
    unawaited(scheduleAll());
  }

  static Future<ReminderUrgency> urgency() async {
    final prefs = await SharedPreferences.getInstance();
    return _stufeAus(prefs);
  }

  /// Die eingestellte Stufe — oder, solange nichts eingestellt ist,
  /// [defaultUrgency].
  ///
  /// Nicht `fromId(null)`: das ergaebe [ReminderUrgency.normal], und eine
  /// Meldung, die sich nicht einblendet, uebersieht man genau dann, wenn man
  /// gerade aufs Handy schaut statt loszufahren. Eine *kaputte* Einstellung
  /// faellt weiter auf `normal` zurueck — die ist nur nicht lesbar, nicht
  /// ungesetzt.
  static ReminderUrgency _stufeAus(SharedPreferences prefs) {
    final gespeichert = prefs.getString(prefUrgency);
    return gespeichert == null
        ? defaultUrgency
        : ReminderUrgency.fromId(gespeichert);
  }

  static Future<void> setUrgency(ReminderUrgency stufe) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefUrgency, stufe.id);
    // Neu stellen: die Stufe steckt im Kanal, und der steht an der schon
    // geplanten Meldung. Ohne das kaeme die naechste noch im alten Ton.
    unawaited(scheduleAll());
  }

  /// Der Kanal zu einer Stufe. Je Stufe ein eigener — siehe
  /// [ReminderUrgency].
  static String channelId(ReminderUrgency stufe) => 'abfahrt_${stufe.id}';

  /// Die Kennung der Meldung zu einem Eintrag.
  ///
  /// Auf 30 Bit gestutzt: Android nimmt nur 32-Bit-Zahlen, und negativ soll
  /// sie auch nicht sein.
  static int notificationId(String eintragId) =>
      'abfahrt:$eintragId'.hashCode & 0x3FFFFFFF;

  // ── Planen ───────────────────────────────────────────────────────────────

  /// Welche Eintraege bekommen eine Meldung, und wann?
  ///
  /// Rein gerechnet, damit es ohne Datenbank und ohne Android pruefbar ist.
  /// Die Termine muessen **aufgeloest** hereinkommen
  /// ([TravelService.resolveAll]): die Anfahrt eines importierten Termins
  /// steht nicht am Termin, sondern beim Kalender.
  static List<Abfahrt> plan({
    required List<CalendarEvent> events,
    required List<Todo> todos,
    required DateTime now,
    required int leadMinutes,
  }) {
    final grenze = now.add(_horizont);
    final out = <Abfahrt>[];

    void nimm({
      required String id,
      required String titel,
      required DateTime start,
      required int fahrt,
    }) {
      if (fahrt <= 0) return;
      if (start.isAfter(grenze)) return;

      // Ueber die Minuten statt mit Duration: in der Nacht der Zeitumstellung
      // haette eine abgezogene Dauer die falsche Uhrzeit.
      final los = DateTime(
          start.year, start.month, start.day, start.hour, start.minute - fahrt);
      // Wer schon haette losfahren muessen, dem hilft kein Hinweis mehr.
      if (!los.isAfter(now)) return;

      var at = DateTime(
          los.year, los.month, los.day, los.hour, los.minute - leadMinutes);
      // Steht die Abfahrt schon innerhalb der Vorlaufzeit, soll die Meldung
      // nicht ausfallen — dann eben gleich.
      if (!at.isAfter(now)) {
        at = now.add(const Duration(minutes: 1));
        if (!at.isBefore(los)) return;
      }
      out.add((
        id: id,
        titel: titel,
        los: los,
        start: start,
        fahrt: fahrt,
        at: at
      ));
    }

    for (final e in events) {
      if (e.isAllDay) continue;
      // Zum Dienstplan eines anderen Menschen faehrt man nicht hin.
      if (e.infoOnly) continue;
      if (e.status == EventStatus.done) continue;
      nimm(
        id: e.id,
        titel: e.title,
        start: e.startTime,
        fahrt: e.travelMinutesBefore,
      );
    }

    for (final t in todos) {
      if (t.status == TodoStatus.done || t.isCompleted) continue;
      final tag = t.scheduledDate;
      final std = t.scheduledStartHour;
      if (tag == null || std == null) continue;
      nimm(
        id: t.id,
        titel: t.title,
        start: DateTime(
            tag.year, tag.month, tag.day, std, t.scheduledStartMinute ?? 0),
        fahrt: t.travelMinutesBefore,
      );
    }

    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Der Text der Meldung.
  ///
  /// Mit Uhrzeit statt „in 5 Minuten": eine Meldung kann liegen bleiben, und
  /// dann waere die Minutenangabe schlicht falsch. „Um 07:40 los" stimmt
  /// auch noch, wenn man erst spaeter hinsieht.
  static String body(Abfahrt a) =>
      'Um ${_hm(a.los)} los — ${a.fahrt} Min. Fahrt, Termin um ${_hm(a.start)}.';

  // ── Stellen ──────────────────────────────────────────────────────────────

  /// Die zuletzt geholten Abo-Termine.
  ///
  /// [scheduleAll] laeuft nach jeder Aenderung an einem Termin oder To-do,
  /// nicht nur beim Start. Dabei jedes Mal alle Abos aus dem Netz zu holen
  /// waere Unfug — bis zu 15 Sekunden je Kalender, mitten im Verschieben.
  /// Also hoechstens einmal je Viertelstunde.
  static List<CalendarEvent> _ics = const [];
  static DateTime? _icsStand;
  static const Duration _icsFrist = Duration(minutes: 15);

  static bool _laeuft = false;
  static bool _nochmal = false;

  /// Plant alle faelligen Meldungen neu. Wirft nie.
  ///
  /// Laeuft immer nur einmal gleichzeitig: zwei Durchgaenge nebeneinander
  /// wuerden sich die Liste der gestellten Meldungen gegenseitig
  /// ueberschreiben, und was dabei durchfaellt, klingelt spaeter ohne Anlass.
  static Future<void> scheduleAll() async {
    if (_laeuft) {
      _nochmal = true;
      return;
    }
    _laeuft = true;
    try {
      do {
        _nochmal = false;
        await _einmalPlanen();
      } while (_nochmal);
    } finally {
      _laeuft = false;
    }
  }

  static Future<void> _einmalPlanen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alt = (prefs.getStringList(_prefGeplant) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

      final neu = <int>{};
      if (prefs.getBool(prefAn) ?? true) {
        final lead = prefs.getInt(prefLead) ?? defaultLeadMinutes;
        final stufe = _stufeAus(prefs);
        final termine = plan(
          events: TravelService.resolveAll(
              [...await LocalService.getAllEvents(), ...await _icsTermine()]),
          todos: await LocalService.getAllTodos(),
          now: DateTime.now(),
          leadMinutes: lead,
        );

        for (final a in termine) {
          final id = notificationId(a.id);
          neu.add(id);
          await ReminderService.scheduleAt(
            id: id,
            title: a.titel,
            body: body(a),
            scheduledAt: a.at,
            channelId: channelId(stufe),
            channelName: 'Losfahren (${stufe.label})',
            channelDescription:
                'Meldet sich, bevor man zu einem Termin losfahren muss.',
            urgency: stufe,
          );
        }
      }

      // Was weg ist oder woanders hin verschoben wurde, soll nicht mehr
      // klingeln.
      for (final id in alt.difference(neu)) {
        await ReminderService.cancel(id);
      }
      await prefs.setStringList(
          _prefGeplant, neu.map((i) => i.toString()).toList());
    } catch (e) {
      FeedbackService.log('Abfahrt-Erinnerungen nicht planbar: $e');
    }
  }

  static Future<List<CalendarEvent>> _icsTermine() async {
    final stand = _icsStand;
    if (stand != null && DateTime.now().difference(stand) < _icsFrist) {
      return _ics;
    }
    try {
      // Ohne die uebernommenen: ein verschobener Abo-Termin liegt als
      // eigener Termin in der Datenbank und kommt trotzdem weiter aus dem
      // Abonnement. Beide zu nehmen hiesse zweimal klingeln, einmal sogar
      // zur alten Uhrzeit.
      _ics = await IcsService.fetchEventsOhneUebernommene();
      _icsStand = DateTime.now();
    } catch (e) {
      // Ohne Netz bleibt der letzte Stand stehen; die eigenen Termine
      // sollen trotzdem ihre Meldung bekommen.
      FeedbackService.log('Abo-Termine fuer die Abfahrt nicht geladen: $e');
    }
    return _ics;
  }

  /// Nimmt die Meldung zu einem Eintrag zurueck — beim Loeschen.
  static Future<void> cancelFor(String eintragId) async {
    try {
      await ReminderService.cancel(notificationId(eintragId));
    } catch (_) {
      // Eine nicht geplante Meldung abzusagen ist kein Fehler.
    }
  }
}
