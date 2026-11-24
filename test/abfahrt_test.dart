import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/reminder_urgency.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/services/departure_reminder_service.dart';
import 'package:kalender/services/ics_service.dart';
import 'package:kalender/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gemeldet wird vor der **Abfahrt**, nicht vor dem Termin: wer um 8:00
/// anfangen muss und 20 Minuten faehrt, will um 7:35 Bescheid bekommen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final jetzt = DateTime(2026, 11, 23, 6, 0);

  CalendarEvent termin({
    String id = 'e1',
    String titel = 'Dienst',
    DateTime? start,
    int fahrt = 20,
    bool ganztags = false,
    bool nurInfo = false,
    EventStatus status = EventStatus.pending,
  }) =>
      CalendarEvent(
        id: id,
        title: titel,
        startTime: start ?? DateTime(2026, 11, 23, 8, 0),
        endTime: (start ?? DateTime(2026, 11, 23, 8, 0))
            .add(const Duration(hours: 4)),
        category: 'work',
        source: 'app',
        isAllDay: ganztags,
        infoOnly: nurInfo,
        status: status,
        travelMinutesBefore: fahrt,
      );

  Todo todo({
    String id = 't1',
    String titel = 'Wäsche',
    DateTime? tag,
    int? std = 9,
    int min = 30,
    int fahrt = 15,
    TodoStatus status = TodoStatus.pending,
  }) =>
      Todo(
        id: id,
        title: titel,
        estimatedMinutes: 30,
        scheduledDate: tag ?? DateTime(2026, 11, 23),
        scheduledStartHour: std,
        scheduledStartMinute: min,
        status: status,
        isCompleted: status == TodoStatus.done,
        travelMinutesBefore: fahrt,
        createdAt: DateTime(2026, 11, 20),
      );

  List<Abfahrt> plane({
    List<CalendarEvent> events = const [],
    List<Todo> todos = const [],
    DateTime? now,
    int vorlauf = 5,
  }) =>
      DepartureReminderService.plan(
        events: events,
        todos: todos,
        now: now ?? jetzt,
        leadMinutes: vorlauf,
      );

  group('Wann gemeldet wird', () {
    test('Vorlauf vor der Abfahrt, nicht vor dem Termin', () {
      final geplant = plane(events: [termin()]);
      expect(geplant, hasLength(1));
      expect(geplant.single.los, DateTime(2026, 11, 23, 7, 40),
          reason: '8:00 minus 20 Minuten Fahrt');
      expect(geplant.single.at, DateTime(2026, 11, 23, 7, 35),
          reason: 'und davon noch die 5 Minuten Vorlauf');
      expect(geplant.single.start, DateTime(2026, 11, 23, 8, 0));
      expect(geplant.single.fahrt, 20);
    });

    test('der Vorgabe-Vorlauf ist 5 Minuten', () {
      expect(DepartureReminderService.defaultLeadMinutes, 5);
    });

    test('ueber die Stundengrenze hinweg', () {
      // 00:10 minus 20 Minuten Fahrt ist der Vortag, nicht 00:-10.
      final geplant = plane(
        events: [termin(start: DateTime(2026, 11, 24, 0, 10))],
        now: DateTime(2026, 11, 23, 20, 0),
      );
      expect(geplant.single.los, DateTime(2026, 11, 23, 23, 50));
      expect(geplant.single.at, DateTime(2026, 11, 23, 23, 45));
    });

    test('nach Meldezeitpunkt sortiert', () {
      final geplant = plane(events: [
        termin(id: 'spaet', start: DateTime(2026, 11, 23, 14, 0)),
        termin(id: 'frueh', start: DateTime(2026, 11, 23, 8, 0)),
      ]);
      expect(geplant.map((a) => a.id), ['frueh', 'spaet']);
    });
  });

  group('Wann nicht gemeldet wird', () {
    test('ohne Anfahrt gibt es nichts loszufahren', () {
      expect(plane(events: [termin(fahrt: 0)]), isEmpty);
    });

    test('Ganztagstermine nicht', () {
      expect(plane(events: [termin(ganztags: true)]), isEmpty);
    });

    test('zum Dienstplan eines anderen Menschen faehrt man nicht', () {
      expect(plane(events: [termin(nurInfo: true)]), isEmpty);
    });

    test('erledigte Termine nicht', () {
      expect(plane(events: [termin(status: EventStatus.done)]), isEmpty);
    });

    test('wer schon losfahren musste, dem hilft kein Hinweis mehr', () {
      // Abfahrt waere 7:40 gewesen, es ist 7:45.
      expect(plane(events: [termin()], now: DateTime(2026, 11, 23, 7, 45)),
          isEmpty);
    });

    test('weiter als eine Woche voraus noch nicht', () {
      expect(plane(events: [termin(start: DateTime(2026, 12, 5, 8, 0))]),
          isEmpty);
      expect(plane(events: [termin(start: DateTime(2026, 11, 29, 8, 0))]),
          hasLength(1), reason: 'sechs Tage liegen noch im Fenster');
    });
  });

  group('Wenn es schon knapp ist', () {
    test('innerhalb der Vorlaufzeit wird gleich gemeldet', () {
      // Es ist 7:37, los geht es 7:40 — der Vorlauf ist schon vorbei.
      final jetztKnapp = DateTime(2026, 11, 23, 7, 37);
      final geplant = plane(events: [termin()], now: jetztKnapp);
      expect(geplant.single.at, jetztKnapp.add(const Duration(minutes: 1)),
          reason: 'lieber gleich als gar nicht');
    });

    test('aber nicht mehr, wenn die Meldung erst nach der Abfahrt kaeme', () {
      // 7:39:30 — die Meldung in einer Minute laege hinter der Abfahrt.
      expect(
          plane(
              events: [termin()], now: DateTime(2026, 11, 23, 7, 39, 30)),
          isEmpty);
    });
  });

  group('To-dos', () {
    test('ein eingeplantes To-do mit Anfahrt bekommt eine Meldung', () {
      final geplant = plane(todos: [todo()]);
      expect(geplant.single.los, DateTime(2026, 11, 23, 9, 15),
          reason: '9:30 minus 15 Minuten Fahrt');
      expect(geplant.single.at, DateTime(2026, 11, 23, 9, 10));
    });

    test('ein ungeplantes nicht', () {
      expect(plane(todos: [todo(std: null)]), isEmpty);
    });

    test('ein abgehaktes nicht', () {
      expect(plane(todos: [todo(status: TodoStatus.done)]), isEmpty);
    });

    test('ohne Anfahrt nicht', () {
      expect(plane(todos: [todo(fahrt: 0)]), isEmpty);
    });
  });

  group('Der Text', () {
    test('nennt Uhrzeiten, keine Minutenangabe', () {
      // „In 5 Minuten losfahren" waere falsch, sobald die Meldung liegen
      // bleibt. Die Uhrzeit stimmt auch dann noch.
      final a = plane(events: [termin()]).single;
      expect(DepartureReminderService.body(a),
          'Um 07:40 los — 20 Min. Fahrt, Termin um 08:00.');
    });
  });

  group('Kennungen und Kanaele', () {
    test('die Meldungs-Kennung ist stabil, verschieden und passt in 32 Bit',
        () {
      final id = DepartureReminderService.notificationId('abc-123');
      expect(id, DepartureReminderService.notificationId('abc-123'));
      expect(id, isNot(DepartureReminderService.notificationId('abc-124')));
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThan(0x40000000));
    });

    test('sie kreuzt sich nicht mit der des Ortsvorschlags', () {
      // Beide haengen an derselben Termin-Kennung. Gleiche Zahl hiesse:
      // eine Meldung loescht die andere.
      expect(DepartureReminderService.notificationId('e1'),
          isNot('ortsvorschlag:e1'.hashCode & 0x3FFFFFFF));
    });

    test('die Probe kommt keiner echten Meldung in die Quere', () {
      // Sonst loescht die Probe ausgerechnet den Hinweis, den sie pruefen
      // soll. Termin-Kennungen sind UUIDs — "__probe__" ist keine.
      final probe = DepartureReminderService.probeId;
      expect(probe, DepartureReminderService.probeId, reason: 'stabil');
      for (final id in ['e1', 't1', '', 'abfahrt', '0']) {
        expect(probe, isNot(DepartureReminderService.notificationId(id)));
      }
      expect(probe, greaterThanOrEqualTo(0));
      expect(probe, lessThan(0x40000000));
    });

    test('je Stufe ein eigener Kanal', () {
      final kanaele = ReminderUrgency.values
          .map(DepartureReminderService.channelId)
          .toSet();
      expect(kanaele, hasLength(ReminderUrgency.values.length),
          reason: 'Android uebernimmt die Wichtigkeit nur beim Anlegen des '
              'Kanals — zwei Stufen im selben Kanal blieben gleich laut');
    });

    test('eine unbekannte Einstellung wird normal, nicht stumm', () {
      expect(ReminderUrgency.fromId(null), ReminderUrgency.normal);
      expect(ReminderUrgency.fromId('quatsch'), ReminderUrgency.normal);
      for (final u in ReminderUrgency.values) {
        expect(ReminderUrgency.fromId(u.id), u);
      }
    });
  });

  group('Die Vorgaben', () {
    test('ohne eingestellte Stufe wird dringend gemeldet, nicht normal', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await DepartureReminderService.urgency(),
          ReminderUrgency.dringend,
          reason: 'eine Meldung, die sich nicht einblendet, uebersieht man '
              'genau dann, wenn man losfahren muesste');
      expect(await DepartureReminderService.leadMinutes(), 5);
      expect(await DepartureReminderService.istAn(), isTrue);
    });

    test('eine eingestellte Stufe gilt', () async {
      SharedPreferences.setMockInitialValues(
          {DepartureReminderService.prefUrgency: 'still'});
      expect(await DepartureReminderService.urgency(), ReminderUrgency.still);
    });

    test('eine kaputte Einstellung faellt auf normal zurueck', () async {
      SharedPreferences.setMockInitialValues(
          {DepartureReminderService.prefUrgency: 'quatsch'});
      expect(await DepartureReminderService.urgency(), ReminderUrgency.normal,
          reason: 'unlesbar ist etwas anderes als ungesetzt');
    });
  });

  group('Uebernommene Abo-Termine', () {
    test('zaehlen nur einmal', () {
      // Ein verschobener Abo-Termin liegt als eigener Termin in der
      // Datenbank und kommt trotzdem weiter aus dem Abonnement. Beide zu
      // nehmen hiesse zweimal klingeln — einmal sogar zur alten Uhrzeit.
      final abo = [
        termin(id: 'abo-1', start: DateTime(2026, 11, 23, 8, 0)),
        termin(id: 'abo-2', start: DateTime(2026, 11, 23, 14, 0)),
      ];
      final uebrig = IcsService.ohneUebernommene(abo, {'abo-1'});
      expect(uebrig.map((e) => e.id), ['abo-2']);

      final eigen = termin(id: 'abo-1', start: DateTime(2026, 11, 23, 9, 0));
      final geplant = plane(events: [eigen, ...uebrig]);
      expect(geplant.map((a) => a.id), ['abo-1', 'abo-2'],
          reason: 'je Eintrag eine Meldung, und zur neuen Uhrzeit');
      expect(geplant.first.start, DateTime(2026, 11, 23, 9, 0));
    });

    test('ohne Uebernahme bleibt alles stehen', () {
      final abo = [termin(id: 'abo-1')];
      expect(IcsService.ohneUebernommene(abo, const {}), hasLength(1));
    });
  });

  group('Wie eindringlich', () {
    AndroidNotificationDetails stufe(ReminderUrgency u) =>
        ReminderService.androidFuer(u,
            channelId: DepartureReminderService.channelId(u),
            channelName: u.label,
            channelDescription: u.beschreibung);

    test('still gibt keinen Ton', () {
      final d = stufe(ReminderUrgency.still);
      expect(d.playSound, isFalse);
      expect(d.enableVibration, isFalse);
      expect(d.importance, Importance.low);
    });

    test('normal gibt Ton, blendet sich aber nicht ein', () {
      final d = stufe(ReminderUrgency.normal);
      expect(d.playSound, isTrue);
      expect(d.importance, Importance.defaultImportance);
    });

    test('dringend blendet sich ein', () {
      expect(stufe(ReminderUrgency.dringend).importance, Importance.high);
    });

    test('Wecker laeuft ueber die Alarm-Lautstaerke', () {
      final d = stufe(ReminderUrgency.alarm);
      expect(d.importance, Importance.max);
      expect(d.audioAttributesUsage, AudioAttributesUsage.alarm,
          reason: 'die Benachrichtigungs-Lautstärke geht beim Stummschalten '
              'mit, die Alarm-Lautstärke nicht');
      expect(d.category, AndroidNotificationCategory.alarm);
      expect(d.vibrationPattern, isNotNull);
    });

    test('die Stufen sind der Reihe nach lauter', () {
      final werte = ReminderUrgency.values
          .map((u) => stufe(u).importance.value)
          .toList();
      for (var i = 1; i < werte.length; i++) {
        expect(werte[i], greaterThan(werte[i - 1]));
      }
    });
  });

  // ── Diagnose ─────────────────────────────────────────────────────────────
  //
  // „Der Wecker geht nicht" kann vier verschiedene Dinge heissen, und von
  // aussen sehen sie gleich aus: nichts geplant, nichts gestellt, Kanal
  // stumm, oder die Meldung kommt nur spaeter. Der Bericht muss sie
  // auseinanderhalten — sonst sucht man wieder im Dunkeln.

  group('Wecker-Diagnose', () {
    const kanalDa = (
      id: 'abfahrt_dringend',
      name: 'Losfahren (Dringend)',
      wichtigkeit: 4,
      ton: true,
      rutteln: true,
    );

    Abfahrt eintrag(String id, {int stunde = 7}) => (
          id: id,
          titel: 'Termin $id',
          los: DateTime(2026, 11, 23, stunde, 40),
          start: DateTime(2026, 11, 23, stunde + 1, 0),
          fahrt: 20,
          at: DateTime(2026, 11, 23, stunde, 35),
        );

    Weckerbefund befund({
      bool an = true,
      int vorlauf = 5,
      ReminderUrgency stufe = ReminderUrgency.dringend,
      bool? darfMelden = true,
      Kanalbefund? kanal = kanalDa,
      List<Abfahrt> geplant = const [],
      Set<int>? gestellt,
      bool gestelltUnbekannt = false,
      bool? probeSteht = false,
      Weckweise? weise = Weckweise.genau,
      Stellversuch versuch = const (weise: Weckweise.genau, fehler: null),
      List<String> protokoll = const [],
    }) =>
        (
          an: an,
          vorlauf: vorlauf,
          stufe: stufe,
          darfMelden: darfMelden,
          kanal: kanal,
          geplant: geplant,
          // Ohne Angabe steht alles Geplante auch wirklich beim Wecker.
          // `gestelltUnbekannt` ist der dritte Fall: Android hat die Frage
          // nicht beantwortet. Weglassen kann das nicht heissen, sonst
          // waere es der Normalfall.
          gestellt: gestelltUnbekannt
              ? null
              : gestellt ??
                  geplant
                      .map((a) => DepartureReminderService.notificationId(a.id))
                      .toSet(),
          probeSteht: probeSteht,
          weise: weise,
          versuch: versuch,
          protokoll: protokoll,
        );

    String text(Weckerbefund b) =>
        DepartureReminderService.bericht(b, now: jetzt);

    // Fast alle Faelle unten setzen voraus, dass der Stellversuch geklappt
    // hat — sonst ist der Fehler die Ursache und alles andere Folge.
    Weckerbefund steht({
      bool an = true,
      int vorlauf = 5,
      ReminderUrgency stufe = ReminderUrgency.dringend,
      bool? darfMelden = true,
      Kanalbefund? kanal = kanalDa,
      List<Abfahrt> geplant = const [],
      Set<int>? gestellt,
      Weckweise? weise = Weckweise.genau,
      List<String> protokoll = const [],
    }) =>
        befund(
          an: an,
          vorlauf: vorlauf,
          stufe: stufe,
          darfMelden: darfMelden,
          kanal: kanal,
          geplant: geplant,
          gestellt: gestellt,
          probeSteht: true,
          weise: weise,
          protokoll: protokoll,
        );

    test('der Schalter kommt vor allem anderen', () {
      final t = text(steht(an: false, geplant: [eintrag('a')]));
      expect(t, contains('Schalter: aus'));
      expect(t, contains('Befund: Der Schalter steht auf aus'));
    });

    test('ohne Erlaubnis kommt nichts an', () {
      final t = text(steht(darfMelden: false, geplant: [eintrag('a')]));
      expect(t, contains('Melden erlaubt: nein'));
      expect(t, contains('lässt die App nicht melden'));
    });

    test('keine Antwort von Android ist nicht dasselbe wie nein', () {
      final t = text(steht(darfMelden: null, geplant: [eintrag('a')]));
      expect(t, contains('Melden erlaubt: keine Antwort von Android'));
      expect(t, isNot(contains('lässt die App nicht melden')),
          reason: 'wer nicht antwortet, hat nicht verboten');
    });

    test('ein blockierter Kanal stellt den Wecker und zeigt nichts', () {
      final t = text(steht(
        kanal: (
          id: 'abfahrt_dringend',
          name: 'Losfahren (Dringend)',
          wichtigkeit: 0,
          ton: false,
          rutteln: false,
        ),
        geplant: [eintrag('a')],
      ));
      expect(t, contains('blockiert'));
      expect(t, contains('Befund: Der Kanal'));
    });

    test('einen Kanal, den es nicht gibt, hat noch nie geklingelt', () {
      final t = text(steht(kanal: null, geplant: [eintrag('a')]));
      expect(t, contains('noch nicht angelegt'));
    });

    test('ohne Anfahrt gibt es nichts zu melden', () {
      final t = text(steht());
      expect(t, contains('Geplant: 0'));
      expect(t, contains('Anfahrtszeit'),
          reason: 'das ist die haeufigste harmlose Ursache und muss '
              'dastehen, bevor jemand nach Fehlern sucht');
    });

    test('Probe steht, echte Meldungen nicht: die Planung lief nicht', () {
      final t = text(steht(geplant: [eintrag('a')], gestellt: const {}));
      expect(t, contains('KEIN Wecker'));
      expect(t, contains('Planung beim Start'));
    });

    test('nur ein Teil steht', () {
      final zwei = [eintrag('a'), eintrag('b', stunde: 9)];
      final t = text(steht(
        geplant: zwei,
        gestellt: {DepartureReminderService.notificationId('a')},
      ));
      expect(t, contains('Geplant: 2, davon beim Wecker: 1'));
      expect(t, contains('Nur 1 von 2'));
    });

    test('ungenau gestellt erklaert die ausgebliebene Probe', () {
      final t = text(
          steht(geplant: [eintrag('a')], weise: Weckweise.ungenau));
      expect(t, contains('Letzte Meldung gestellt: ungefähr'));
      expect(t, contains('nur ungefähr'));
      expect(t, contains('15'),
          reason: 'genau das ist die Erklaerung fuer den Test-Knopf');
    });

    test('steht alles weckgenau, verschluckt es das Handy', () {
      final t = text(steht(geplant: [eintrag('a')]));
      expect(t, contains('Die Wecker stehen alle'));
      expect(t, contains('Akkusparen'));
    });

    test('jede Meldung steht mit Uhrzeit und Zustand im Bericht', () {
      final t = text(steht(geplant: [eintrag('a')]));
      expect(
          t,
          contains('heute 07:35 — Termin a '
              '(Abfahrt 07:40, Termin 08:00): Wecker steht'));
    });

    test('lange Listen werden abgekuerzt', () {
      final viele = [
        for (var i = 0; i < 8; i++) eintrag('e$i', stunde: 7 + i),
      ];
      final t = text(steht(geplant: viele));
      expect(t, contains('Geplant: 8'));
      expect(t, contains('und 3 weitere'));
    });

    test('stehen() zaehlt nur die geplanten, nicht fremde Wecker', () {
      final b = steht(
        geplant: [eintrag('a')],
        gestellt: {DepartureReminderService.notificationId('a'), 4711},
      );
      expect(DepartureReminderService.stehen(b), 1);
      expect(text(b), contains('Wecker insgesamt gestellt: 2'));
    });

    test('ein Fehler beim Stellen ist die Ursache, nicht die Folge', () {
      final t = text(befund(
        geplant: [eintrag('a')],
        gestellt: const {},
        versuch: const (
          weise: null,
          fehler: 'PlatformException [kaputt] so nicht',
        ),
      ));
      expect(t, contains('Stellversuch jetzt: PlatformException [kaputt]'));
      expect(t, contains('Das Stellen selbst schlägt fehl'));
      expect(t, contains('so nicht'),
          reason: 'der Text von Android muss wortwoertlich dastehen');
    });

    test('angenommen und doch nicht gemerkt: der Empfaenger fehlt', () {
      final t = text(befund(geplant: [eintrag('a')], probeSteht: false));
      expect(t, contains('Probe steht danach: nein'));
      expect(t, contains('merkt sie sich aber nicht'));
    });

    test('das Protokoll kommt mit, die juengste Zeile zuerst', () {
      final t = text(steht(
        geplant: [eintrag('a')],
        protokoll: const ['[07:00:01] Abfahrt-Meldung nicht stellbar: boom'],
      ));
      expect(t, contains('Protokoll:'));
      expect(t, contains('Abfahrt-Meldung nicht stellbar: boom'));
    });

    test('ohne Protokollzeilen fehlt die Ueberschrift', () {
      expect(text(steht(geplant: [eintrag('a')])),
          isNot(contains('Protokoll:')));
    });

    test('nicht feststellbar ist nicht dasselbe wie keine', () {
      final t = text(befund(
        geplant: [eintrag('a')],
        gestelltUnbekannt: true,
        probeSteht: null,
      ));
      expect(t, contains('davon beim Wecker: nicht feststellbar'));
      expect(t, contains('Wecker insgesamt gestellt: nicht feststellbar'));
      expect(t, contains('Termin a (Abfahrt 07:40, Termin 08:00): unklar'));
      expect(t, isNot(contains('KEIN Wecker')),
          reason: 'wir wissen es nicht — behaupten duerfen wir es nicht');
      expect(t, contains('kann gar nicht sagen'));
      expect(
        DepartureReminderService.stehen(befund(gestelltUnbekannt: true)),
        isNull,
      );
    });

    test('Vorlauf, Stufe und Kanal stehen oben', () {
      final t = text(steht(vorlauf: 20, stufe: ReminderUrgency.alarm));
      expect(t, contains('Vorlauf: 20 Min.'));
      expect(t, contains('Stufe: Wie ein Wecker (Kanal abfahrt_alarm)'));
    });
  });

  group('Wie gestellt wurde', () {
    test('was in der Vergangenheit liegt, wird gar nicht gestellt', () async {
      // Vor jedem Zugriff aufs Plugin: darum laeuft das auch ohne Android.
      final weise = await ReminderService.scheduleAt(
        id: 1,
        title: 'Vorbei',
        body: 'schon vorbei',
        scheduledAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(weise, Weckweise.garnicht);
    });

    test('ohne gestellte Meldung weiss niemand von einer Weckweise', () {
      expect(ReminderService.zuletztGestellt, isNull);
    });

    test('die Stufen tragen ihre Beschriftung mit', () {
      expect(Weckweise.genau.label, 'weckgenau');
      expect(Weckweise.ungenau.label, 'ungefähr');
      expect(Weckweise.garnicht.label, 'gar nicht gestellt');
    });
  });

  group('Der Zeitpunkt haengt nicht an tz.local', () {
    // tz.local ist ein late-Feld ohne Vorgabe. Faesst man es an, bevor
    // initializeTimeZones() gelaufen ist, wirft es — und zwar bevor Android
    // ueberhaupt gefragt wird. Dann faellt jede geplante Meldung aus,
    // waehrend show() weiter geht. Dieser Test laeuft genau in dem Zustand:
    // in main() kommt initialize() zuerst, hier nie.
    test('ohne initializeTimeZones wirft das Rechnen nicht', () {
      expect(() => ReminderService.zeitpunkt(DateTime(2026, 11, 26, 4, 55)),
          returnsNormally);
    });

    test('der Zeitpunkt bleibt derselbe Moment', () {
      final wann = DateTime(2026, 11, 26, 4, 55);
      expect(ReminderService.zeitpunkt(wann).millisecondsSinceEpoch,
          wann.millisecondsSinceEpoch,
          reason: 'die Zone aendert die Darstellung, nicht den Augenblick');
    });

    test('und die Wanduhr, die das Plugin schickt, passt dazu', () {
      final z = ReminderService.zeitpunkt(DateTime.utc(2026, 11, 26, 4, 55));
      expect(z.toIso8601String(), startsWith('2026-11-26T04:55:00'));
    });
  });

  group('Fehler lesbar machen', () {
    test('der code einer PlatformException steht vorn', () {
      final t = ReminderService.fehlertext(PlatformException(
          code: 'exact_alarms_not_permitted', message: 'nicht erlaubt'));
      expect(t, 'PlatformException [exact_alarms_not_permitted] '
          'nicht erlaubt');
    });

    test('eine Ausnahme ohne Text bleibt trotzdem brauchbar', () {
      expect(ReminderService.fehlertext(PlatformException(code: 'leer')),
          contains('[leer] ohne Text'));
    });

    test('Details kommen mit, wenn es welche gibt', () {
      expect(
          ReminderService.fehlertext(PlatformException(
              code: 'x', message: 'y', details: 'Stapel')),
          endsWith('/ Stapel'));
    });

    test('alles andere mit Typ', () {
      expect(ReminderService.fehlertext(StateError('kaputt')),
          contains('StateError'));
    });
  });

  group('Nachfragen stuerzen nicht ab', () {
    // Ohne Android antwortet das Plugin mit einem Fehler. Eine Diagnose, die
    // daran stirbt, hilft niemandem — darum faengt jede Frage ihren Fehler
    // selbst, und das muss auch so bleiben.
    test('darf melden? ohne Plattform: keine Antwort', () async {
      expect(await ReminderService.darfMelden(), isNull);
    });

    test('gestellte Kennungen ohne Plattform: unbekannt, nicht leer',
        () async {
      // Der Unterschied ist der ganze Punkt. Das Plugin liest die Liste aus
      // derselben Ablage, in die es beim Stellen schreibt: geht das Stellen
      // kaputt, geht auch das Nachsehen kaputt. Wer daraus „es steht kein
      // Wecker" macht, zeigt auf die falsche Stelle.
      expect(await ReminderService.geplanteKennungen(), isNull);
    });

    test('Kanal ohne Plattform: unbekannt statt Fehler', () async {
      expect(await ReminderService.kanal('abfahrt_dringend'), isNull);
    });

    test('die ganze Diagnose laeuft auch ohne Android durch', () async {
      SharedPreferences.setMockInitialValues({
        DepartureReminderService.prefAn: true,
        DepartureReminderService.prefLead: 7,
        DepartureReminderService.prefUrgency: 'alarm',
      });
      final b = await DepartureReminderService.diagnose();
      expect(b.an, isTrue);
      expect(b.vorlauf, 7);
      expect(b.stufe, ReminderUrgency.alarm);
      expect(b.gestellt, isNull);
      expect(b.probeSteht, isNull);
      // Ohne Plattform muss der Stellversuch scheitern — und gefangen sein.
      expect(b.versuch.fehler, isNotNull);
      expect(b.versuch.weise, isNull);
      expect(b.protokoll, isNotEmpty,
          reason: 'der gefangene Fehler gehoert ins Protokoll');
      // Der Bericht muss aus dem Befund in jedem Fall herauskommen.
      expect(DepartureReminderService.bericht(b, now: jetzt),
          contains('Wecker zum Losfahren'));
    });
  });
}
