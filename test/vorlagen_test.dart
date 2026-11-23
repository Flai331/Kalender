import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/models/vorlage.dart';
import 'package:kalender/services/local_service.dart';
import 'package:kalender/services/vorlagen_service.dart';
import 'package:kalender/vorlagen/vorlagensuche.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// „Dienst Spaet" ist immer acht Stunden lang, hat 20 Minuten Anfahrt und
/// zehn zurueck. Das jedes Mal neu einzustellen ist Arbeit fuer nichts —
/// die Vorlage traegt es, der Titel ruft es ab.
///
/// Hier wird geprueft, was eine Vorlage mitnimmt (alles Eingestellte), was
/// sie *nicht* mitnimmt (alles, was zu einem einzelnen Eintrag gehoert) und
/// was beim Auflegen stehen bleibt (die Zeit, die schon gewaehlt wurde).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CalendarEvent dienst() => CalendarEvent(
        id: 'e1',
        title: 'Dienst Spät',
        description: 'Wache 3',
        startTime: DateTime(2026, 3, 2, 14, 0),
        endTime: DateTime(2026, 3, 2, 22, 0),
        category: 'work',
        isFixed: true,
        address: 'Hauptstraße 1',
        placeGroup: 'Wachen',
        travelBeforeOverride: 20,
        travelAfterOverride: 10,
        status: EventStatus.started,
        actualStart: DateTime(2026, 3, 2, 14, 3),
        pausedMinutes: 7,
        outlookEventId: 'ol-1',
        icsSourceId: 'ics_42',
      );

  Todo einkauf() => Todo(
        id: 't1',
        title: 'Großeinkauf',
        description: 'Liste am Kühlschrank',
        estimatedMinutes: 90,
        category: 'personal',
        createdAt: DateTime(2026, 1, 1),
        scheduledDate: DateTime(2026, 3, 2),
        scheduledStartHour: 17,
        scheduledStartMinute: 30,
        status: TodoStatus.started,
        actualStart: DateTime(2026, 3, 2, 17, 31),
        pausedMinutes: 4,
        address: 'Markt 2',
        travelMinutesBefore: 15,
        travelMinutesAfter: 25,
        dueWindowStartHour: 9,
        dueWindowEndHour: 20,
        contextMode: TodoContextMode.freeTime,
        requiredCategory: 'work',
        requiredCalendarId: 'app',
        allowedWeekdays: const [1, 3, 5],
        daylightMode: DaylightMode.gps,
        subTasks: [
          SubTask(id: 's1', title: 'Pfand', isDone: true),
          SubTask(id: 's2', title: 'Obst'),
        ],
      );

  Vorlage vonTermin(CalendarEvent e) =>
      Vorlage.ausTermin(e, id: 'v1', jetzt: DateTime(2026, 3, 1));
  Vorlage vonTodo(Todo t) =>
      Vorlage.ausTodo(t, id: 'v2', jetzt: DateTime(2026, 3, 1));

  group('Was eine Vorlage mitnimmt', () {
    test('die Dauer des Termins, nicht seine Uhrzeit', () {
      final v = vonTermin(dienst());
      expect(v.dauerMinuten, 480);
      expect(v.felder.containsKey('startTime'), isFalse);
      expect(v.felder.containsKey('endTime'), isFalse);
    });

    test('alles Eingestellte', () {
      final v = vonTermin(dienst());
      expect(v.felder['category'], 'work');
      expect(v.felder['travelBeforeOverride'], 20);
      expect(v.felder['travelAfterOverride'], 10);
      expect(v.felder['address'], 'Hauptstraße 1');
      expect(v.felder['placeGroup'], 'Wachen');
      expect(v.felder['isFixed'], isTrue);
      expect(v.felder['description'], 'Wache 3');
    });

    test('nichts, was zu diesem einen Termin gehoert', () {
      final v = vonTermin(dienst());
      for (final weg in [
        'id',
        'status',
        'actualStart',
        'actualEnd',
        'pausedMinutes',
        'pauseStart',
        'source',
        'outlookEventId',
        'icsSourceId',
      ]) {
        expect(v.felder.containsKey(weg), isFalse, reason: '$weg muss weg');
      }
    });

    test('der Titel steht in name und nicht in den Feldern', () {
      final v = vonTermin(dienst());
      expect(v.name, 'Dienst Spät');
      // Stuende er auch in den Feldern, setzte eine umbenannte Vorlage
      // weiter den alten Titel.
      expect(v.felder.containsKey('title'), isFalse);
    });

    test('beim To-do die Einstellungen, nicht der Platz im Kalender', () {
      final v = vonTodo(einkauf());
      expect(v.felder['estimatedMinutes'], 90);
      expect(v.felder['travelMinutesBefore'], 15);
      expect(v.felder['travelMinutesAfter'], 25);
      expect(v.felder['dueWindowStartHour'], 9);
      expect(v.felder['contextMode'], TodoContextMode.freeTime.name);
      expect(v.felder['requiredCalendarId'], 'app');
      expect(v.felder['allowedWeekdays'], [1, 3, 5]);
      expect(v.felder['daylightMode'], DaylightMode.gps.name);
      expect(v.felder.containsKey('scheduledDate'), isFalse);
      expect(v.felder.containsKey('scheduledStartHour'), isFalse);
      expect(v.felder.containsKey('createdAt'), isFalse);
      expect(v.felder.containsKey('status'), isFalse);
    });

    test('die Checkliste ohne Haken', () {
      final v = vonTodo(einkauf());
      final teile = (v.felder['subTasks'] as List).cast<Map>();
      expect(teile.length, 2);
      expect(teile.every((t) => t['isDone'] == false), isTrue);
    });

    test('ueber JSON hin und zurueck', () {
      final v = vonTermin(dienst());
      final zurueck = Vorlage.fromJson(v.toJson());
      expect(zurueck.id, v.id);
      expect(zurueck.art, Vorlagenart.termin);
      expect(zurueck.name, v.name);
      expect(zurueck.dauerMinuten, 480);
      expect(zurueck.felder['travelBeforeOverride'], 20);
      expect(zurueck.zuletztBenutzt, v.zuletztBenutzt);
    });
  });

  group('Die Vorlage legt sich ueber einen Termin', () {
    CalendarEvent frisch() => CalendarEvent(
          id: 'neu',
          title: '',
          startTime: DateTime(2026, 5, 4, 9, 0),
          endTime: DateTime(2026, 5, 4, 10, 0),
        );

    test('der gewaehlte Beginn bleibt, das Ende rueckt auf die Dauer', () {
      final e = vonTermin(dienst()).aufTermin(frisch());
      expect(e.startTime, DateTime(2026, 5, 4, 9, 0));
      expect(e.endTime, DateTime(2026, 5, 4, 17, 0));
    });

    test('Kennung und Titel', () {
      final e = vonTermin(dienst()).aufTermin(frisch());
      expect(e.id, 'neu');
      expect(e.title, 'Dienst Spät');
    });

    test('alles Eingestellte kommt mit', () {
      final e = vonTermin(dienst()).aufTermin(frisch());
      expect(e.category, 'work');
      expect(e.travelBeforeOverride, 20);
      expect(e.travelAfterOverride, 10);
      expect(e.address, 'Hauptstraße 1');
      expect(e.placeGroup, 'Wachen');
      expect(e.isFixed, isTrue);
    });

    test('der Stand des bestehenden Termins bleibt', () {
      final laufend = frisch();
      final bestand = CalendarEvent(
        id: laufend.id,
        title: 'Irgendwas',
        startTime: laufend.startTime,
        endTime: laufend.endTime,
        status: EventStatus.started,
        actualStart: DateTime(2026, 5, 4, 9, 2),
        pausedMinutes: 12,
        outlookEventId: 'ol-9',
        icsSourceId: 'ics_7',
      );
      final e = vonTermin(dienst()).aufTermin(bestand);
      expect(e.status, EventStatus.started);
      expect(e.actualStart, DateTime(2026, 5, 4, 9, 2));
      expect(e.pausedMinutes, 12);
      expect(e.outlookEventId, 'ol-9');
      expect(e.icsSourceId, 'ics_7');
    });

    test('eine umbenannte Vorlage setzt den neuen Titel', () {
      final e =
          vonTermin(dienst()).umbenannt('Dienst Nacht').aufTermin(frisch());
      expect(e.title, 'Dienst Nacht');
    });
  });

  group('Die Vorlage legt sich ueber ein To-do', () {
    Todo frisch() => Todo(
          id: 'neu',
          title: '',
          createdAt: DateTime(2026, 5, 1),
          scheduledDate: DateTime(2026, 5, 4),
          scheduledStartHour: 8,
          scheduledStartMinute: 15,
          status: TodoStatus.started,
          actualStart: DateTime(2026, 5, 4, 8, 16),
        );

    test('der Platz im Kalender bleibt, wo er ist', () {
      final t = vonTodo(einkauf()).aufTodo(frisch());
      expect(t.scheduledDate, DateTime(2026, 5, 4));
      expect(t.scheduledStartHour, 8);
      expect(t.scheduledStartMinute, 15);
      expect(t.createdAt, DateTime(2026, 5, 1));
      expect(t.status, TodoStatus.started);
      expect(t.actualStart, DateTime(2026, 5, 4, 8, 16));
    });

    test('die Einstellungen kommen aus der Vorlage', () {
      final t = vonTodo(einkauf()).aufTodo(frisch());
      expect(t.title, 'Großeinkauf');
      expect(t.estimatedMinutes, 90);
      expect(t.travelMinutesBefore, 15);
      expect(t.travelMinutesAfter, 25);
      expect(t.contextMode, TodoContextMode.freeTime);
      expect(t.requiredCategory, 'work');
      expect(t.requiredCalendarId, 'app');
      expect(t.allowedWeekdays, [1, 3, 5]);
      expect(t.daylightMode, DaylightMode.gps);
      expect(t.dueWindowStartHour, 9);
      expect(t.dueWindowEndHour, 20);
      expect(t.subTasks.map((s) => s.title), ['Pfand', 'Obst']);
      expect(t.subTasks.every((s) => !s.isDone), isTrue);
    });
  });

  group('Speichern und wiederfinden', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await LocalService.init(db);
      VorlagenService.resetForTesting();
    });
    tearDown(() async => db.close());

    test('eine gemerkte Vorlage steht in der Datenbank', () async {
      await VorlagenService.ausTermin(dienst());
      final gespeichert = await LocalService.getVorlagen();
      expect(gespeichert.length, 1);
      expect(gespeichert.first.name, 'Dienst Spät');
      expect(gespeichert.first.dauerMinuten, 480);
    });

    test('nach einem Neustart ist sie noch da', () async {
      await VorlagenService.ausTermin(dienst());
      VorlagenService.resetForTesting();
      final liste = await VorlagenService.laden();
      expect(liste.length, 1);
      expect(liste.first.name, 'Dienst Spät');
    });

    test('Termin- und To-do-Vorlagen bleiben getrennt', () async {
      await VorlagenService.ausTermin(dienst());
      await VorlagenService.ausTodo(einkauf());
      expect((await VorlagenService.fuer(Vorlagenart.termin)).length, 1);
      expect((await VorlagenService.fuer(Vorlagenart.todo)).length, 1);
      expect((await VorlagenService.fuer(Vorlagenart.termin)).first.name,
          'Dienst Spät');
    });

    test('derselbe Titel bessert nach, statt zu verdoppeln', () async {
      final erst = await VorlagenService.ausTermin(dienst());
      await VorlagenService.benutzt(erst.id);
      final e = dienst();
      final geaendert = CalendarEvent(
        id: e.id,
        title: e.title,
        startTime: e.startTime,
        endTime: e.startTime.add(const Duration(hours: 6)),
        category: 'personal',
      );
      final neu = await VorlagenService.ausTermin(geaendert);

      final alle = await VorlagenService.fuer(Vorlagenart.termin);
      expect(alle.length, 1);
      expect(neu.id, erst.id, reason: 'die Kennung bleibt');
      expect(alle.first.dauerMinuten, 360);
      expect(alle.first.felder['category'], 'personal');
      expect(alle.first.benutzt, 1, reason: 'der Zaehler bleibt');
    });

    test('Benutzen zaehlt hoch', () async {
      final v = await VorlagenService.ausTermin(dienst());
      await VorlagenService.benutzt(v.id);
      await VorlagenService.benutzt(v.id);
      final alle = await VorlagenService.fuer(Vorlagenart.termin);
      expect(alle.first.benutzt, 2);
    });

    test('Umbenennen setzt den neuen Namen', () async {
      final v = await VorlagenService.ausTermin(dienst());
      expect(await VorlagenService.umbenennen(v.id, 'Dienst Nacht'), isTrue);
      final alle = await VorlagenService.fuer(Vorlagenart.termin);
      expect(alle.first.name, 'Dienst Nacht');
      expect(alle.first.benutzt, 0);
    });

    test('zwei gleichnamige Vorlagen derselben Art gibt es nicht', () async {
      await VorlagenService.ausTermin(dienst());
      final zweite = await VorlagenService.ausTermin(CalendarEvent(
        id: 'e2',
        title: 'Dienst Früh',
        startTime: DateTime(2026, 3, 3, 6, 0),
        endTime: DateTime(2026, 3, 3, 14, 0),
      ));
      expect(await VorlagenService.umbenennen(zweite.id, 'Dienst Spät'),
          isFalse);
      final alle = await VorlagenService.fuer(Vorlagenart.termin);
      expect(alle.map((v) => v.name),
          containsAll(['Dienst Spät', 'Dienst Früh']));
    });

    test('ein leerer Name wird nicht genommen', () async {
      final v = await VorlagenService.ausTermin(dienst());
      expect(await VorlagenService.umbenennen(v.id, '   '), isFalse);
      expect((await VorlagenService.fuer(Vorlagenart.termin)).first.name,
          'Dienst Spät');
    });

    test('Loeschen nimmt sie aus der Datenbank', () async {
      final v = await VorlagenService.ausTermin(dienst());
      await VorlagenService.loeschen(v.id);
      expect(await VorlagenService.fuer(Vorlagenart.termin), isEmpty);
      expect(await LocalService.getVorlagen(), isEmpty);
    });

    test('jede Aenderung meldet sich ueber die revision', () async {
      final vorher = VorlagenService.revision.value;
      final v = await VorlagenService.ausTermin(dienst());
      expect(VorlagenService.revision.value, greaterThan(vorher));
      final dazwischen = VorlagenService.revision.value;
      await VorlagenService.loeschen(v.id);
      expect(VorlagenService.revision.value, greaterThan(dazwischen));
    });

    test('die Suche findet die gemerkte Vorlage trotz Tippfehler', () async {
      await VorlagenService.ausTermin(dienst());
      final vorrat = await VorlagenService.fuer(Vorlagenart.termin);
      expect(Vorlagensuche.passend(vorrat, 'diesnt').map((v) => v.name),
          ['Dienst Spät']);
    });
  });
}
