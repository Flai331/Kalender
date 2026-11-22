import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/services/place_reminder_service.dart';

/// Wann meldet sich die App, und zu welchem Termin?
///
/// Der Vorschlag kommt nicht beim Anlegen, sondern bevor der Termin
/// ansteht — das war die Entscheidung. Also muss der Zeitpunkt stimmen.
void main() {
  CalendarEvent termin({
    String id = 'e1',
    required DateTime start,
    String? gruppe = 'Fitnessstudio',
    bool ganztags = false,
    EventStatus status = EventStatus.pending,
  }) =>
      CalendarEvent(
        id: id,
        title: 'Sport',
        startTime: start,
        endTime: DateTime(
            start.year, start.month, start.day, start.hour + 1, start.minute),
        placeGroup: gruppe,
        isAllDay: ganztags,
        status: status,
      );

  final jetzt = DateTime(2026, 11, 23, 9);

  List<({CalendarEvent event, DateTime at})> plan(
    List<CalendarEvent> events, {
    int vorlauf = 90,
    DateTime? now,
  }) =>
      PlaceReminderService.plan(
        events: events,
        now: now ?? jetzt,
        leadMinutes: vorlauf,
      );

  group('Wann gemeldet wird', () {
    test('die Vorlaufzeit vor dem Termin', () {
      final e = termin(start: DateTime(2026, 11, 23, 18));
      expect(plan([e]).single.at, DateTime(2026, 11, 23, 16, 30));
    });

    test('kürzerer Vorlauf wird genommen', () {
      final e = termin(start: DateTime(2026, 11, 23, 18));
      expect(plan([e], vorlauf: 30).single.at, DateTime(2026, 11, 23, 17, 30));
    });

    test('über Mitternacht zurück bleibt richtig', () {
      final e = termin(start: DateTime(2026, 11, 24, 0, 30));
      expect(plan([e], vorlauf: 90).single.at,
          DateTime(2026, 11, 23, 23, 0));
    });

    test('ein Termin kurz vor der Tür meldet sich sofort statt gar nicht', () {
      // In einer Stunde, Vorlauf 90 Minuten: der Zeitpunkt läge schon hinter
      // uns. Dann lieber gleich.
      final e = termin(start: DateTime(2026, 11, 23, 10));
      final geplant = plan([e]).single;
      expect(geplant.at.isAfter(jetzt), isTrue);
      expect(geplant.at.isBefore(e.startTime), isTrue);
    });

    test('ein laufender oder vergangener Termin meldet sich nicht', () {
      expect(plan([termin(start: DateTime(2026, 11, 23, 8))]), isEmpty);
      expect(plan([termin(start: jetzt)]), isEmpty);
    });

    test('mehrere Termine in der Reihenfolge, in der sie dran sind', () {
      final spaet = termin(id: 'a', start: DateTime(2026, 11, 24, 18));
      final frueh = termin(id: 'b', start: DateTime(2026, 11, 23, 18));
      expect(plan([spaet, frueh]).map((t) => t.event.id).toList(),
          ['b', 'a']);
    });
  });

  group('Wer gemeldet wird', () {
    test('ohne Gruppe keine Meldung', () {
      expect(plan([termin(start: DateTime(2026, 11, 23, 18), gruppe: null)]),
          isEmpty);
      expect(plan([termin(start: DateTime(2026, 11, 23, 18), gruppe: '  ')]),
          isEmpty);
    });

    test('ganztägige Termine haben keine Uhrzeit zum Melden', () {
      expect(
          plan([termin(start: DateTime(2026, 11, 23, 18), ganztags: true)]),
          isEmpty);
    });

    test('ein erledigter Termin meldet sich nicht mehr', () {
      expect(
          plan([
            termin(
                start: DateTime(2026, 11, 23, 18), status: EventStatus.done)
          ]),
          isEmpty);
    });

    test('weit in der Zukunft wird noch nicht geplant', () {
      expect(plan([termin(start: DateTime(2026, 11, 23, 18))]), hasLength(1));
      expect(plan([termin(start: DateTime(2026, 12, 20, 18))]), isEmpty);
    });
  });

  group('Nutzlast', () {
    test('Termin-Kennung geht hin und kommt zurück', () {
      final roh = PlaceReminderService.payloadFor('abc-123');
      expect(PlaceReminderService.eventIdFromPayload(roh), 'abc-123');
    });

    test('fremde Meldungen öffnen keinen Vorschlag', () {
      expect(PlaceReminderService.eventIdFromPayload(null), isNull);
      expect(PlaceReminderService.eventIdFromPayload(''), isNull);
      expect(PlaceReminderService.eventIdFromPayload('kein JSON'), isNull);
      expect(PlaceReminderService.eventIdFromPayload('{"typ":"etwas"}'),
          isNull);
      expect(
          PlaceReminderService.eventIdFromPayload('{"typ":"ortsvorschlag"}'),
          isNull);
    });

    test('die Kennung der Meldung passt zu Android und bleibt gleich', () {
      final id = PlaceReminderService.notificationId('abc-123');
      expect(id, PlaceReminderService.notificationId('abc-123'));
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThan(1 << 30));
      expect(id, isNot(PlaceReminderService.notificationId('abc-124')));
    });
  });

  test('der Text sagt die Uhrzeit und die Gruppe', () {
    final e = termin(start: DateTime(2026, 11, 23, 18, 5));
    final text = PlaceReminderService.body(e, 90);
    expect(text, contains('18:05'));
    expect(text, contains('Fitnessstudio'));
  });

  test('der Termin trägt die Gruppe durch Speichern und Laden', () {
    final e = termin(start: DateTime(2026, 11, 23, 18));
    final zurueck = CalendarEvent.fromJson(e.toJson());
    expect(zurueck.placeGroup, 'Fitnessstudio');
    expect(zurueck.copyWith(placeGroup: null).placeGroup, isNull);
    expect(zurueck.copyWith(title: 'Anders').placeGroup, 'Fitnessstudio');
  });
}
