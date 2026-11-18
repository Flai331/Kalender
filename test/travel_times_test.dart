import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/travel_times.dart';
import 'package:kalender/services/travel_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An-/Abfahrtszeiten sollen auf Kalender-Ebene gelten, aber je Serie und je
/// Termin uebersteuerbar sein — auch fuer importierte Kalender.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TravelService.resetForTesting();
    await TravelService.load();
  });

  CalendarEvent eigener({int? before, int? after}) => CalendarEvent(
        id: 'e1',
        title: 'Zahnarzt',
        startTime: DateTime(2026, 11, 18, 10),
        endTime: DateTime(2026, 11, 18, 11),
        travelBeforeOverride: before,
        travelAfterOverride: after,
      );

  CalendarEvent importiert({
    String id = 'ics_1',
    String uid = 'uid-serie',
    String quelle = 'quelle-a',
  }) =>
      CalendarEvent(
        id: id,
        title: 'Training',
        startTime: DateTime(2026, 11, 18, 18),
        endTime: DateTime(2026, 11, 18, 19, 30),
        source: 'ics',
        outlookEventId: uid,
        icsSourceId: quelle,
      );

  group('Rangfolge', () {
    test('ohne jede Einstellung gilt keine Zeit', () {
      final r = TravelService.resolve(eigener());
      expect(r.travelMinutesBefore, 0);
      expect(r.travelMinutesAfter, 0);
    });

    test('Kalender-Vorgabe gilt fuer alles in diesem Kalender', () async {
      await TravelService.setCalendarTimes(
          TravelService.ownCalendarId, const TravelTimes(before: 15, after: 10));

      final r = TravelService.resolve(eigener());
      expect(r.travelMinutesBefore, 15);
      expect(r.travelMinutesAfter, 10);
    });

    test('der Termin sticht die Kalender-Vorgabe', () async {
      await TravelService.setCalendarTimes(
          TravelService.ownCalendarId, const TravelTimes(before: 15, after: 10));

      final r = TravelService.resolve(eigener(before: 45));
      expect(r.travelMinutesBefore, 45);
      expect(r.travelMinutesAfter, 10,
          reason: 'nur die Anfahrt war eigen, die Abfahrt erbt weiter');
    });

    test('eine ausdrueckliche Null sticht die Kalender-Vorgabe', () async {
      await TravelService.setCalendarTimes(
          TravelService.ownCalendarId, const TravelTimes(before: 15, after: 10));

      final r = TravelService.resolve(eigener(before: 0));
      expect(r.travelMinutesBefore, 0,
          reason: '„keine Anfahrt" muss sich gegen die Vorgabe sagen lassen');
    });

    test('Serie sticht Kalender, Termin sticht Serie', () async {
      await TravelService.setCalendarTimes(
          'quelle-a', const TravelTimes(before: 5, after: 5));
      await TravelService.setSeriesTimes(
          'ics:uid-serie', const TravelTimes(before: 30));

      final ev = importiert();
      expect(TravelService.resolve(ev).travelMinutesBefore, 30);
      expect(TravelService.resolve(ev).travelMinutesAfter, 5,
          reason: 'die Serie sagt zur Abfahrt nichts');

      await TravelService.setEventTimes(ev.id, const TravelTimes(before: 60));
      expect(TravelService.resolve(ev).travelMinutesBefore, 60);
    });
  });

  group('Importierte Kalender', () {
    test('die Serie wirkt auf alle Vorkommen', () async {
      await TravelService.setSeriesTimes(
          'ics:uid-serie', const TravelTimes(before: 20, after: 20));

      // Zwei Termine derselben Serie: verschiedene Kennung, gleiche UID.
      final mo = importiert(id: 'ics_mo');
      final di = importiert(id: 'ics_di');

      expect(TravelService.resolve(mo).travelMinutesBefore, 20);
      expect(TravelService.resolve(di).travelMinutesBefore, 20);
    });

    test('ein einzelnes Vorkommen laesst sich herausnehmen', () async {
      await TravelService.setSeriesTimes(
          'ics:uid-serie', const TravelTimes(before: 20, after: 20));
      await TravelService.setEventTimes(
          'ics_di', const TravelTimes(before: 0, after: 0));

      expect(TravelService.resolve(importiert(id: 'ics_mo')).travelMinutesBefore,
          20);
      expect(TravelService.resolve(importiert(id: 'ics_di')).travelMinutesBefore,
          0);
    });

    test('jede Quelle hat ihre eigene Vorgabe', () async {
      await TravelService.setCalendarTimes(
          'quelle-a', const TravelTimes(before: 10));
      await TravelService.setCalendarTimes(
          'quelle-b', const TravelTimes(before: 40));

      expect(
          TravelService.resolve(importiert(quelle: 'quelle-a'))
              .travelMinutesBefore,
          10);
      expect(
          TravelService.resolve(importiert(quelle: 'quelle-b'))
              .travelMinutesBefore,
          40);
    });

    test('ein importierter Termin traegt seine Zeit nicht selbst', () {
      expect(TravelService.storesOwnTimes(importiert()), isFalse);
      expect(TravelService.storesOwnTimes(eigener()), isTrue);
    });

    test('eigene Termine haben keinen Serien-Schluessel', () {
      expect(TravelService.seriesKeyOf(eigener()), isNull);
      expect(TravelService.seriesKeyOf(importiert()), 'ics:uid-serie');
    });
  });

  group('Speichern', () {
    test('aufgeloeste Werte landen nicht in der Datenbank', () async {
      await TravelService.setCalendarTimes(
          TravelService.ownCalendarId, const TravelTimes(before: 15, after: 10));

      final aufgeloest = TravelService.resolve(eigener());
      expect(aufgeloest.travelMinutesBefore, 15);

      // So wuerde der Termin gespeichert — etwa nach einem Verschieben.
      final json = jsonDecode(jsonEncode(aufgeloest.toJson()))
          as Map<String, dynamic>;
      expect(json['travelBeforeOverride'], isNull,
          reason: 'sonst fror die Vorgabe von heute am Termin ein');

      // Und nach dem Zuruecklesen erbt er weiter: neue Vorgabe greift.
      await TravelService.setCalendarTimes(
          TravelService.ownCalendarId, const TravelTimes(before: 25));
      final zurueck = TravelService.resolve(CalendarEvent.fromJson(json));
      expect(zurueck.travelMinutesBefore, 25);
    });

    test('eigene Zeiten ueberleben das Speichern', () {
      final json = eigener(before: 35, after: 0).toJson();
      final zurueck = CalendarEvent.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>);

      expect(zurueck.travelBeforeOverride, 35);
      expect(zurueck.travelAfterOverride, 0);
    });

    test('„Vorgabe" laesst sich wieder einstellen', () {
      final zurueck = CalendarEvent.fromJson(
          jsonDecode(jsonEncode(eigener(before: 35).copyWith(
            travelBeforeOverride: null,
          ).toJson())) as Map<String, dynamic>);

      expect(zurueck.travelBeforeOverride, isNull);
    });

    test('leere Einstellung wird nicht behalten', () async {
      await TravelService.setCalendarTimes(
          'quelle-a', const TravelTimes(before: 10));
      await TravelService.setCalendarTimes('quelle-a', const TravelTimes());

      expect(TravelService.calendarTimes('quelle-a').isEmpty, isTrue);
    });

    test('Einstellungen ueberleben einen Neustart', () async {
      await TravelService.setCalendarTimes(
          'quelle-a', const TravelTimes(before: 12, after: 7));
      await TravelService.setSeriesTimes(
          'ics:uid-serie', const TravelTimes(before: 3));

      TravelService.resetForTesting();
      await TravelService.load();

      expect(TravelService.calendarTimes('quelle-a'),
          const TravelTimes(before: 12, after: 7));
      expect(TravelService.seriesTimes('ics:uid-serie').before, 3);
    });
  });

  group('Altbestand', () {
    test('ein alter Termin behaelt seine Zeit als eigene', () {
      // So sah ein Termin vor der Vererbung aus.
      final alt = {
        'id': 'alt',
        'title': 'Alter Termin',
        'startTime': DateTime.utc(2026, 11, 18, 9).toIso8601String(),
        'endTime': DateTime.utc(2026, 11, 18, 10).toIso8601String(),
        'travelMinutesBefore': 20,
        'travelMinutesAfter': 25,
      };
      final ev = CalendarEvent.fromJson(alt);

      expect(ev.travelBeforeOverride, 20);
      expect(ev.travelAfterOverride, 25);
    });

    test('eine alte Null bleibt „keine Anfahrt"', () async {
      await TravelService.setCalendarTimes(
          TravelService.ownCalendarId, const TravelTimes(before: 15));

      final alt = CalendarEvent.fromJson({
        'id': 'alt',
        'title': 'Alter Termin',
        'startTime': DateTime.utc(2026, 11, 18, 9).toIso8601String(),
        'endTime': DateTime.utc(2026, 11, 18, 10).toIso8601String(),
        'travelMinutesBefore': 0,
        'travelMinutesAfter': 0,
      });

      expect(TravelService.resolve(alt).travelMinutesBefore, 0,
          reason: 'bestehende Termine duerfen sich nicht von selbst aendern');
    });

    test('ein Termin ohne jede Angabe erbt', () async {
      await TravelService.setCalendarTimes(
          TravelService.ownCalendarId, const TravelTimes(before: 15));

      final ohne = CalendarEvent.fromJson({
        'id': 'ohne',
        'title': 'Ohne Angabe',
        'startTime': DateTime.utc(2026, 11, 18, 9).toIso8601String(),
        'endTime': DateTime.utc(2026, 11, 18, 10).toIso8601String(),
      });

      expect(TravelService.resolve(ohne).travelMinutesBefore, 15);
    });
  });
}
