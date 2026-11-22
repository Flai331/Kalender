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
}
