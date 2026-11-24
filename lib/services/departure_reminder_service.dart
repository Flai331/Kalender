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

/// Was beim Stellen wirklich herauskam.
///
/// Entweder eine [Weckweise] oder ein Fehler, nie beides. Der Punkt ist der
/// Fehler: ein fehlgeschlagenes `zonedSchedule` verschwand bisher im
/// Protokoll, und die App sagte nur „es kommt nichts".
typedef Stellversuch = ({Weckweise? weise, String? fehler});

/// Was der Wecker zum Losfahren gerade wirklich tut.
///
/// Gesammelt, nicht geraten: die Einstellung kommt aus den Vorgaben, der
/// Plan aus [DepartureReminderService.plan], und ob ein Wecker steht, sagt
/// Android selbst. Genau daran scheiterte die Suche bisher — „es kommt
/// nichts" kann heissen, dass nichts geplant war, dass das Stellen
/// fehlschlug, dass der Kanal stumm ist oder dass die Meldung noch kommt.
/// Vier verschiedene Dinge, und von aussen sahen sie gleich aus.
typedef Weckerbefund = ({
  bool an,
  int vorlauf,
  ReminderUrgency stufe,

  /// Ob die App melden darf. `null`: Android hat nicht geantwortet.
  bool? darfMelden,

  /// Der Kanal zur eingestellten Stufe — null, wenn es ihn noch nicht gibt.
  Kanalbefund? kanal,

  /// Was gemeldet werden soll.
  List<Abfahrt> geplant,

  /// Welche Kennungen wirklich beim Wecker stehen — auch fremde.
  Set<int> gestellt,

  /// Ob die Probe aus dem Test-Knopf noch aussteht.
  bool probeSteht,

  /// Wie die letzte Meldung gestellt wurde ([ReminderService.zuletztGestellt]).
  Weckweise? weise,

  /// Was ein frischer Versuch ergab — der eigentliche Test.
  Stellversuch versuch,

  /// Die Zeilen aus dem Protokoll, die den Wecker betreffen, die jüngste
  /// zuerst. Hier steht der Grund, wenn das Stellen fehlschlaegt.
  List<String> protokoll,
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

  /// Die Kennung der Probe-Meldung.
  ///
  /// Aus einer Zeichenkette gerechnet, die als Kennung eines Termins oder
  /// To-dos nicht vorkommt — so kann die Probe keiner echten Meldung in die
  /// Quere kommen und wird von [_einmalPlanen] auch nicht wieder abgesagt.
  static int get probeId => notificationId('__probe__');

  /// Stellt eine Probe in ein paar Sekunden — mit der Stufe, die gerade
  /// eingestellt ist.
  ///
  /// Der Punkt ist nicht der Text, sondern der **Weg**: Wecker ueber den
  /// AlarmManager, Empfaenger im Manifest, Kanal der gewaehlten Stufe. Genau
  /// dieser Weg lief lange ins Leere, ohne dass es auffiel — die
  /// Test-Meldung in den Einstellungen benutzte `show()` und brauchte ihn
  /// gar nicht.
  static Future<Weckweise> probeStellen(ReminderUrgency stufe,
      {Duration warte = const Duration(seconds: 15)}) async {
    return ReminderService.scheduleAt(
      id: probeId,
      title: 'Probe: Losfahren',
      body: 'So meldet sich „${stufe.label}". Echte Hinweise kommen genauso.',
      scheduledAt: DateTime.now().add(warte),
      channelId: channelId(stufe),
      channelName: 'Losfahren (${stufe.label})',
      channelDescription:
          'Meldet sich, bevor man zu einem Termin losfahren muss.',
      urgency: stufe,
    );
  }

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
          try {
            final weise = await ReminderService.scheduleAt(
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
            // Nur was wirklich steht, wird vermerkt. Sonst gilt beim
            // naechsten Durchgang als „schon gestellt", was nie stand, und
            // bekommt nie wieder einen Versuch.
            if (weise != Weckweise.garnicht) neu.add(id);
          } catch (e) {
            // Eine Meldung, die Android ablehnt, darf nicht alle anderen
            // mitnehmen: vorher brach der ganze Durchgang hier ab, die Liste
            // der gestellten Wecker wurde nicht einmal geschrieben — und ein
            // einziger kaputter Termin liess den Wecker verstummen.
            FeedbackService.log(
                'Abfahrt-Meldung fuer "${a.titel}" nicht stellbar: $e');
          }
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

  // ── Diagnose ─────────────────────────────────────────────────────────────

  /// Fragt alles ab, was erklaeren kann, warum nichts klingelt.
  ///
  /// Wirft nicht: jede Frage an Android faengt ihre Fehler selbst, und ohne
  /// Datenbank bleibt der Plan eben leer. Eine Diagnose, die abstuerzt, ist
  /// schlimmer als keine.
  static Future<Weckerbefund> diagnose() async {
    final prefs = await SharedPreferences.getInstance();
    final vorlauf = prefs.getInt(prefLead) ?? defaultLeadMinutes;
    final stufe = _stufeAus(prefs);

    // Zuerst wirklich stellen, dann nachsehen, ob es angekommen ist. Der
    // Weg selbst ist die Frage — alles andere drumherum war schon in
    // Ordnung, als nichts kam.
    final versuch = await probeVersuch(stufe);

    var termine = const <Abfahrt>[];
    try {
      termine = plan(
        events: TravelService.resolveAll(
            [...await LocalService.getAllEvents(), ...await _icsTermine()]),
        todos: await LocalService.getAllTodos(),
        now: DateTime.now(),
        leadMinutes: vorlauf,
      );
    } catch (e) {
      FeedbackService.log('Diagnose: Plan nicht berechenbar: $e');
    }

    final gestellt = await ReminderService.geplanteKennungen();
    return (
      versuch: versuch,
      protokoll: _protokoll(),
      an: prefs.getBool(prefAn) ?? true,
      vorlauf: vorlauf,
      stufe: stufe,
      darfMelden: await ReminderService.darfMelden(),
      kanal: await ReminderService.kanal(channelId(stufe)),
      geplant: termine,
      gestellt: gestellt,
      probeSteht: gestellt.contains(probeId),
      weise: ReminderService.zuletztGestellt,
    );
  }

  /// Stellt eine Probe und faengt den Fehler, statt ihn wegzuwerfen.
  ///
  /// Genau hier bricht es ab, wenn „die zweite Meldung nicht kommt": der
  /// Fehler flog bisher aus dem Knopf heraus ins Nichts.
  static Future<Stellversuch> probeVersuch(ReminderUrgency stufe) async {
    try {
      return (weise: await probeStellen(stufe), fehler: null);
    } catch (e) {
      final text = ReminderService.fehlertext(e);
      FeedbackService.log('Probe nicht stellbar: $text');
      return (weise: null, fehler: text);
    }
  }

  /// Die letzten Protokollzeilen, die mit dem Wecker zu tun haben.
  ///
  /// Beim Start plant [scheduleAll] alles — scheitert das, steht der Grund
  /// schon da, bevor jemand die Diagnose oeffnet.
  static List<String> _protokoll() {
    const worte = ['Abfahrt', 'Meldung', 'Erinnerung', 'Wecker', 'Probe'];
    return FeedbackService.logEntries
        .where((z) => worte.any(z.contains))
        .toList()
        .reversed
        .take(6)
        .toList();
  }

  /// Wie viele der geplanten Meldungen wirklich beim Wecker stehen.
  static int stehen(Weckerbefund b) => b.geplant
      .where((a) => b.gestellt.contains(notificationId(a.id)))
      .length;

  /// Der Befund als Text — zum Lesen und zum Mitschicken.
  ///
  /// Rein gerechnet, ohne Android und ohne Datenbank: so ist jede Zeile
  /// pruefbar, und derselbe Text taugt im Fehlerbericht.
  static String bericht(Weckerbefund b, {required DateTime now}) {
    final z = <String>[
      'Wecker zum Losfahren',
      'Schalter: ${b.an ? 'an' : 'aus'}',
      'Vorlauf: ${b.vorlauf} Min. vor der Abfahrt',
      'Stufe: ${b.stufe.label} (Kanal ${channelId(b.stufe)})',
      'Melden erlaubt: ${_jaNein(b.darfMelden)}',
      _kanalZeile(b.kanal),
    ];

    final offen = stehen(b);
    z.add('Geplant: ${b.geplant.length}, davon beim Wecker: $offen');
    for (final a in b.geplant.take(_zeilen)) {
      final steht = b.gestellt.contains(notificationId(a.id));
      z.add('  ${_wann(a.at, now)} — ${a.titel} '
          '(Abfahrt ${_hm(a.los)}, Termin ${_hm(a.start)}): '
          '${steht ? 'Wecker steht' : 'KEIN Wecker'}');
    }
    if (b.geplant.length > _zeilen) {
      z.add('  … und ${b.geplant.length - _zeilen} weitere');
    }
    z.add('Wecker insgesamt gestellt: ${b.gestellt.length}');
    z.add('Letzte Meldung gestellt: ${b.weise?.label ?? 'seit dem Start '
        'keine'}');
    z.add('Stellversuch jetzt: '
        '${b.versuch.fehler ?? b.versuch.weise?.label ?? 'nicht versucht'}');
    z.add('Probe steht danach: ${b.probeSteht ? 'ja' : 'nein'}');
    if (b.protokoll.isNotEmpty) {
      z.add('');
      z.add('Protokoll:');
      for (final zeile in b.protokoll) {
        z.add('  $zeile');
      }
    }
    z.add('');
    z.add('Befund: ${_befund(b, offen)}');
    return z.join('\n');
  }

  /// Wie viele Zeilen der Bericht einzeln aufzaehlt.
  static const int _zeilen = 5;

  static String _jaNein(bool? wert) => wert == null
      ? 'keine Antwort von Android'
      : wert
          ? 'ja'
          : 'nein';

  static String _kanalZeile(Kanalbefund? k) {
    if (k == null) {
      return 'Kanal: noch nicht angelegt — in dieser Stufe hat es noch nie '
          'geklingelt';
    }
    final aus = [
      if (!k.ton) 'Ton aus',
      if (!k.rutteln) 'Vibration aus',
    ];
    return 'Kanal: ${_wichtig(k.wichtigkeit)}'
        '${aus.isEmpty ? '' : ', ${aus.join(', ')}'}';
  }

  /// Was eine Kanal-Wichtigkeit bedeutet. Android gibt die Zahl zurueck, die
  /// der Benutzer in den Systemeinstellungen gesetzt hat — nicht die, die
  /// die App beim Anlegen wollte.
  static String _wichtig(int wert) => switch (wert) {
        0 => 'blockiert — so kommt nichts an',
        1 => 'minimal, nur in der Leiste',
        2 => 'leise, ohne Ton',
        3 => 'normal, mit Ton',
        4 => 'hoch, mit Ton und Einblendung',
        5 => 'höchste',
        _ => 'unbekannt ($wert)',
      };

  /// Wann etwas ist, kurz genug fuer eine Zeile.
  static String _wann(DateTime t, DateTime now) {
    final tage = DateTime(t.year, t.month, t.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (tage == 0) return 'heute ${_hm(t)}';
    if (tage == 1) return 'morgen ${_hm(t)}';
    return '${t.day}.${t.month}. ${_hm(t)}';
  }

  /// Der Satz, auf den es ankommt.
  ///
  /// Die Reihenfolge ist die Reihenfolge der Ursachen: was weiter vorn steht,
  /// macht alles Weitere ohnehin wirkungslos. Ein ausgeschalteter Schalter
  /// erklaert ein leeres Ergebnis vollstaendig, ein blockierter Kanal
  /// erklaert einen stehenden Wecker, der nichts zeigt.
  static String _befund(Weckerbefund b, int gestellt) {
    if (!b.an) {
      return 'Der Schalter steht auf aus — es wird nichts gemeldet.';
    }
    if (b.darfMelden == false) {
      return 'Android lässt die App nicht melden. In den '
          'Android-Einstellungen unter „Benachrichtigungen" erlauben.';
    }
    final fehler = b.versuch.fehler;
    if (fehler != null) {
      return 'Das Stellen selbst schlägt fehl: $fehler — das ist die '
          'Ursache, alles andere ist Folge.';
    }
    if (b.versuch.weise != null && !b.probeSteht) {
      return 'Android nimmt die Meldung an, merkt sie sich aber nicht: der '
          'Versuch lief ohne Fehler durch, und danach steht trotzdem kein '
          'Wecker. Das passt zu einem Empfänger, den das System nicht '
          'auflösen kann.';
    }
    final k = b.kanal;
    if (k != null && k.wichtigkeit == 0) {
      return 'Der Kanal „${k.name}" ist in den Android-Einstellungen '
          'blockiert. Der Wecker wird dann gestellt, aber nichts gezeigt.';
    }
    if (b.geplant.isEmpty) {
      return 'Es gibt nichts zu melden: kein Termin und kein To-do in den '
          'nächsten 7 Tagen hat eine Anfahrtszeit. Ohne Anfahrt gibt es '
          'nichts loszufahren — die Zeit steht am Termin selbst oder als '
          'Vorgabe beim Kalender.';
    }
    if (gestellt == 0) {
      return 'Die Probe steht, die echten Meldungen nicht. Die Planung beim '
          'Start ist also nicht durchgelaufen — ein Mal einen Termin '
          'speichern stellt sie neu.';
    }
    if (b.weise == Weckweise.ungenau) {
      return 'Die Wecker stehen, aber nur ungefähr: weckgenaue Meldungen '
          'sind nicht erlaubt. Android legt sie dann mit anderen zusammen '
          'und darf sie um viele Minuten verschieben — eine Probe nach 15 '
          'Sekunden kommt so erst viel später. Erlauben unter '
          'Android-Einstellungen → Apps → Kalender → „Weckerzeiten und '
          'Erinnerungen".';
    }
    if (gestellt < b.geplant.length) {
      return 'Nur $gestellt von ${b.geplant.length} Meldungen stehen beim '
          'Wecker. Die übrigen hat Android abgelehnt; der Grund steht im '
          'Protokoll.';
    }
    return 'Die Wecker stehen alle, und zwar weckgenau. Kommt trotzdem '
        'nichts, verschluckt es das Handy: Kanal leiser gestellt, oder das '
        'Akkusparen hält die App an. Unter Android-Einstellungen → Apps → '
        'Kalender → Akku auf „Unbeschränkt" stellen.';
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
