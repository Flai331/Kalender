import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/ics_source.dart';
import 'package:kalender/models/travel_times.dart';
import 'package:kalender/services/ics_service.dart';
import 'package:kalender/services/place_reminder_service.dart';
import 'package:kalender/services/travel_service.dart';
import 'package:kalender/week/week_day_column.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Nur zur Info" — zum Beispiel der Dienstplan eines anderen Menschen.
///
/// So ein Termin soll im Kalender stehen und sonst **nichts** tun: keine Zeit
/// belegen, kein To-do verhindern, keine An- und Abfahrt erben und sich nicht
/// melden. Hier steht, dass er in jeder dieser Rechnungen wirklich übersprungen
/// wird — nicht nur blasser gemalt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CalendarEvent termin({
    String id = 'e1',
    bool nurInfo = false,
    String? gruppe,
    String? quelle,
    DateTime? start,
  }) {
    final s = start ?? DateTime(2026, 11, 23, 8);
    return CalendarEvent(
      id: id,
      title: 'Dienst Mama',
      startTime: s,
      endTime: DateTime(s.year, s.month, s.day, s.hour + 8, s.minute),
      infoOnly: nurInfo,
      placeGroup: gruppe,
      source: quelle == null ? 'local' : 'ics',
      icsSourceId: quelle,
      outlookEventId: quelle == null ? null : 'uid-1',
    );
  }

  group('Termin-Modell', () {
    test('normaler Termin ist nicht nur zur Info', () {
      expect(termin().infoOnly, isFalse);
    });

    test('der Schalter übersteht das Speichern', () {
      final zurueck =
          CalendarEvent.fromJson(termin(nurInfo: true).toJson());
      expect(zurueck.infoOnly, isTrue);
      expect(zurueck.title, 'Dienst Mama');
    });

    test('Altbestand ohne das Feld redet weiter mit', () {
      final alt = termin().toJson()..remove('infoOnly');
      expect(CalendarEvent.fromJson(alt).infoOnly, isFalse);
    });

    test('copyWith kann an und wieder aus', () {
      final an = termin().copyWith(infoOnly: true);
      expect(an.infoOnly, isTrue);
      expect(an.copyWith(infoOnly: false).infoOnly, isFalse);
    });

    test('copyWith ohne Angabe lässt den Schalter stehen', () {
      final an = termin(nurInfo: true);
      expect(an.copyWith(title: 'Spätdienst').infoOnly, isTrue);
    });
  });

  group('Kalender-Modell', () {
    test('neuer Kalender redet mit', () {
      const q = IcsSource(id: '1', name: 'Dienstplan', url: 'https://x/a.ics');
      expect(q.infoOnly, isFalse);
    });

    test('Altbestand ohne das Feld redet mit', () {
      final q = IcsSource.fromJson({
        'id': '1',
        'name': 'Dienstplan',
        'url': 'https://x/a.ics',
        'isFile': false,
        'color': null,
        'allowTodoDrop': false,
      });
      expect(q.infoOnly, isFalse);
    });

    test('nur zur Info übersteht das Speichern', () {
      const q = IcsSource(id: '1', name: 'Dienstplan', url: 'https://x/a.ics');
      final zurueck = IcsSource.listFromJson(
          IcsSource.listToJson([q.copyWith(infoOnly: true)])).single;
      expect(zurueck.infoOnly, isTrue);
      expect(zurueck.name, 'Dienstplan');
    });

    test('Umschalten lässt Farbe und Sichtbarkeit stehen', () {
      const q = IcsSource(
        id: '1',
        name: 'Dienstplan',
        url: 'https://x/a.ics',
        color: 0xFF448AFF,
      );
      final info = q.copyWith(infoOnly: true);
      expect(info.color, 0xFF448AFF);
      expect(info.visible, isTrue);
    });
  });

  group('Abonnierter Kalender', () {
    const zweiTermine = '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:dienst-1
SUMMARY:Frühdienst
DTSTART:20261123T060000Z
DTEND:20261123T140000Z
END:VEVENT
BEGIN:VEVENT
UID:dienst-2
SUMMARY:Spätdienst
DTSTART:20261124T140000Z
DTEND:20261124T220000Z
END:VEVENT
END:VCALENDAR''';

    late Directory ordner;
    late File datei;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ordner = await Directory.systemTemp.createTemp('ics_nur_info');
      datei = File('${ordner.path}/dienstplan.ics');
      await datei.writeAsString(zweiTermine);
    });

    tearDown(() async {
      if (ordner.existsSync()) await ordner.delete(recursive: true);
    });

    test('ohne den Schalter reden die Termine mit', () async {
      await IcsService.addFile(datei.path, 'Dienstplan');
      final termine = await IcsService.fetchEvents();
      expect(termine, hasLength(2));
      expect(termine.every((e) => e.infoOnly), isFalse);
    });

    test('der Schalter gilt für jeden Termin des Kalenders', () async {
      final q = await IcsService.addFile(datei.path, 'Dienstplan');
      await IcsService.saveSources([q.copyWith(infoOnly: true)]);

      final termine = await IcsService.fetchEvents();
      expect(termine, hasLength(2));
      expect(termine.every((e) => e.infoOnly), isTrue);
      expect(termine.map((e) => e.title), ['Frühdienst', 'Spätdienst']);
    });

    test('nur der eine Kalender wird still, der andere nicht', () async {
      final zweite = File('${ordner.path}/eigenes.ics');
      await zweite.writeAsString(zweiTermine.replaceAll('dienst-', 'eigen-'));

      final a = await IcsService.addFile(datei.path, 'Dienstplan');
      await IcsService.addFile(zweite.path, 'Eigenes');
      final quellen = await IcsService.getSources();
      await IcsService.saveSources(quellen
          .map((s) => s.id == a.id ? s.copyWith(infoOnly: true) : s)
          .toList());

      final termine = await IcsService.fetchEvents();
      final info = termine.where((e) => e.infoOnly).toList();
      expect(info, hasLength(2));
      expect(info.every((e) => e.icsSourceId == a.id), isTrue);
      expect(termine.where((e) => !e.infoOnly), hasLength(2));
    });

    test('wieder zurückgeschaltet reden sie wieder mit', () async {
      final q = await IcsService.addFile(datei.path, 'Dienstplan');
      await IcsService.saveSources([q.copyWith(infoOnly: true)]);
      await IcsService.saveSources([q.copyWith(infoOnly: false)]);

      final termine = await IcsService.fetchEvents();
      expect(termine.any((e) => e.infoOnly), isFalse);
    });
  });

  group('An- und Abfahrt', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      TravelService.resetForTesting();
      await TravelService.load();
    });

    test('ein eigener Termin erbt die Vorgabe des Kalenders', () async {
      await TravelService.setCalendarTimes(TravelService.ownCalendarId,
          const TravelTimes(before: 20, after: 15));

      final r = TravelService.resolve(termin());
      expect(r.travelMinutesBefore, 20);
      expect(r.travelMinutesAfter, 15);
    });

    test('zu einem Info-Termin fährt man nicht hin', () async {
      await TravelService.setCalendarTimes(TravelService.ownCalendarId,
          const TravelTimes(before: 20, after: 15));

      final r = TravelService.resolve(termin(nurInfo: true));
      expect(r.travelMinutesBefore, 0);
      expect(r.travelMinutesAfter, 0);
    });

    test('auch ein eigener Wert am Termin wird übergangen', () {
      final e = termin(nurInfo: true)
          .copyWith(travelBeforeOverride: 30, travelAfterOverride: 30);
      final r = TravelService.resolve(e);
      expect(r.travelMinutesBefore, 0);
      expect(r.travelMinutesAfter, 0);
    });

    test('auch die Vorgabe des abonnierten Kalenders wird übergangen',
        () async {
      await TravelService.setCalendarTimes(
          'dienstplan', const TravelTimes(before: 25, after: 25));

      final r = TravelService.resolve(
          termin(nurInfo: true, quelle: 'dienstplan'));
      expect(r.travelMinutesBefore, 0);
      expect(r.travelMinutesAfter, 0);
    });
  });

  group('Ortsvorschlag', () {
    final jetzt = DateTime(2026, 11, 23, 9);

    test('ein eigener Termin mit Gruppe bekommt einen Vorschlag', () {
      final geplant = PlaceReminderService.plan(
        events: [
          termin(gruppe: 'Fitnessstudio', start: DateTime(2026, 11, 23, 18))
        ],
        now: jetzt,
        leadMinutes: 90,
      );
      expect(geplant, hasLength(1));
      expect(geplant.single.at, DateTime(2026, 11, 23, 16, 30));
    });

    test('ein Info-Termin meldet sich nicht', () {
      final geplant = PlaceReminderService.plan(
        events: [
          termin(
              nurInfo: true,
              gruppe: 'Fitnessstudio',
              start: DateTime(2026, 11, 23, 18))
        ],
        now: jetzt,
        leadMinutes: 90,
      );
      expect(geplant, isEmpty);
    });

    test('der eigene Termin bleibt, der fremde fällt weg', () {
      final geplant = PlaceReminderService.plan(
        events: [
          termin(
              id: 'fremd',
              nurInfo: true,
              gruppe: 'Fitnessstudio',
              start: DateTime(2026, 11, 23, 17)),
          termin(
              id: 'eigen',
              gruppe: 'Fitnessstudio',
              start: DateTime(2026, 11, 23, 18)),
        ],
        now: jetzt,
        leadMinutes: 90,
      );
      expect(geplant.map((p) => p.event.id), ['eigen']);
    });
  });

  group('Uebernehmen (fremder Kalender wird eigener Termin)', () {
    test('die Markierung kommt mit', () {
      final eigen = termin(nurInfo: true, quelle: 'dienstplan')
          .adoptedAsOwn(newId: 'neu-1');
      expect(eigen.infoOnly, isTrue);
      expect(eigen.id, 'neu-1');
      expect(eigen.title, 'Dienst Mama');
    });

    test('die Herkunft faellt ab', () {
      final eigen = termin(nurInfo: true, quelle: 'dienstplan')
          .adoptedAsOwn(newId: 'neu-1');
      expect(eigen.source, 'app');
      expect(eigen.icsSourceId, isNull);
      expect(eigen.outlookEventId, isNull);
    });

    test('ein gewoehnlicher Termin bleibt gewoehnlich', () {
      final eigen =
          termin(quelle: 'arbeit').adoptedAsOwn(newId: 'neu-2');
      expect(eigen.infoOnly, isFalse);
    });

    test('Uhrzeit, Ort und Gruppe ueberleben', () {
      final quelle = termin(nurInfo: true, gruppe: 'Fitnessstudio')
          .copyWith(address: 'Klinikum, Hauptstr. 1');
      final eigen = quelle.adoptedAsOwn(newId: 'neu-3');
      expect(eigen.startTime, quelle.startTime);
      expect(eigen.endTime, quelle.endTime);
      expect(eigen.address, 'Klinikum, Hauptstr. 1');
      expect(eigen.placeGroup, 'Fitnessstudio');
    });

    test('An-/Abfahrt kommt von aussen und wird uebernommen', () {
      final eigen = termin().adoptedAsOwn(
          newId: 'neu-4', travelBeforeOverride: 20, travelAfterOverride: 15);
      expect(eigen.travelBeforeOverride, 20);
      expect(eigen.travelAfterOverride, 15);
    });
  });

  group('Verschieben in der Wochenansicht', () {
    testWidgets('auch ein Info-Termin laesst sich ziehen', (t) async {
      SharedPreferences.setMockInitialValues({});
      TravelService.resetForTesting();
      await TravelService.load();

      final tag = DateTime(2026, 11, 23);
      CalendarEvent block(String id, int von, int bis, {bool info = false}) =>
          CalendarEvent(
            id: id,
            title: id,
            startTime: DateTime(tag.year, tag.month, tag.day, von),
            endTime: DateTime(tag.year, tag.month, tag.day, bis),
            infoOnly: info,
          );

      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 600,
            child: WeekDayColumn(
              day: tag,
              events: [
                block('fremd', 8, 14, info: true),
                block('eigen', 10, 11),
              ],
              todos: const [],
              isToday: true,
              hourHeight: 60,
              startHour: 8,
              endHour: 15,
              onTodoDrop: (_, __, ___, ____) {},
              onEventDrop: (_, __, ___, ____) {},
              onEventTap: (_) {},
              onTodoTap: (_) {},
              onTodoToggleDone: (_) {},
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();

      // Beide Bloecke haengen an einem Zieh-Griff — der fremde Dienstplan
      // aendert sich, und dann will man ihn nachziehen koennen.
      expect(find.byType(LongPressDraggable<CalendarEvent>), findsNWidgets(2));
    });
  });
}
