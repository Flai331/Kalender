import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/series_reminder.dart';
import 'package:kalender/services/reminder_service.dart';

/// Die Serien-Erinnerungen fragten bisher die Microsoft-Graph-API ab. Die war
/// nie eingerichtet, also stand im Bildschirm immer "Kein Outlook verbunden"
/// und keine Fallback-Regel konnte je greifen. Ausloeser sind jetzt die
/// abonnierten ICS-Kalender — der Weg, auf dem Outlook-Termine wirklich in
/// der App landen.
void main() {
  CalendarEvent termin(
    String titel,
    DateTime start, {
    String quelle = 'arbeit',
    Duration dauer = const Duration(hours: 1),
    bool ganztag = false,
  }) =>
      CalendarEvent(
        id: '$titel-${start.toIso8601String()}',
        title: titel,
        startTime: start,
        endTime: start.add(dauer),
        isAllDay: ganztag,
        source: 'outlook',
        icsSourceId: quelle,
      );

  final tag = DateTime(2026, 12, 7);

  Future<CalendarEvent?> suche(
    List<CalendarEvent> termine, {
    String stichwort = 'Spätdienst',
    String? quelle,
  }) =>
      ReminderService.findEventOnDay(
          day: tag, keyword: stichwort, sourceId: quelle, events: termine);

  group('Auslöser-Termin finden', () {
    test('Treffer am richtigen Tag', () async {
      final gefunden = await suche([
        termin('Spätdienst Station 3', DateTime(2026, 12, 7, 14)),
      ]);
      expect(gefunden?.title, 'Spätdienst Station 3');
    });

    test('Stichwort zählt ohne Rücksicht auf Groß- und Kleinschreibung',
        () async {
      final gefunden = await suche([
        termin('SPÄTDIENST', DateTime(2026, 12, 7, 14)),
      ]);
      expect(gefunden, isNotNull);
    });

    test('anderer Tag zählt nicht', () async {
      final gefunden = await suche([
        termin('Spätdienst', DateTime(2026, 12, 8, 14)),
        termin('Spätdienst', DateTime(2026, 12, 6, 14)),
      ]);
      expect(gefunden, isNull);
    });

    test('anderes Stichwort zählt nicht', () async {
      final gefunden = await suche([
        termin('Frühdienst', DateTime(2026, 12, 7, 6)),
      ]);
      expect(gefunden, isNull);
    });

    test('ohne Stichwort zählt jeder Termin des Tages', () async {
      final gefunden = await suche([
        termin('Zahnarzt', DateTime(2026, 12, 7, 9)),
      ], stichwort: '');
      expect(gefunden?.title, 'Zahnarzt');
    });

    test('ein gewählter Kalender schließt die anderen aus', () async {
      final termine = [
        termin('Spätdienst', DateTime(2026, 12, 7, 14), quelle: 'privat'),
        termin('Spätdienst', DateTime(2026, 12, 7, 15), quelle: 'arbeit'),
      ];
      expect((await suche(termine, quelle: 'arbeit'))?.startTime.hour, 15);
      expect((await suche(termine, quelle: 'privat'))?.startTime.hour, 14);
      expect((await suche(termine, quelle: 'weg')), isNull,
          reason: 'ein geloeschter Kalender darf nichts liefern');
    });

    test('ohne gewählten Kalender zählen alle', () async {
      final gefunden = await suche([
        termin('Spätdienst', DateTime(2026, 12, 7, 14), quelle: 'privat'),
      ]);
      expect(gefunden, isNotNull);
    });

    test('bei mehreren Treffern gewinnt der früheste', () async {
      final gefunden = await suche([
        termin('Spätdienst spät', DateTime(2026, 12, 7, 20)),
        termin('Spätdienst früh', DateTime(2026, 12, 7, 6)),
        termin('Spätdienst mittags', DateTime(2026, 12, 7, 12)),
      ]);
      expect(gefunden?.title, 'Spätdienst früh');
    });

    test('ganztägiger Termin über mehrere Tage zählt mit', () async {
      final gefunden = await suche([
        termin('Spätdienst-Woche', DateTime(2026, 12, 5),
            dauer: const Duration(days: 5), ganztag: true),
      ]);
      expect(gefunden, isNotNull);
    });

    test('Termin um Mitternacht gehört zu seinem Tag', () async {
      final gefunden = await suche([
        termin('Spätdienst', DateTime(2026, 12, 7, 0, 0)),
      ]);
      expect(gefunden, isNotNull);
    });

    test('nichts abonniert heißt kein Treffer', () async {
      expect(await suche([]), isNull);
    });
  });

  group('Gespeicherte Erinnerungen', () {
    test('der neue Schlüssel übersteht das Speichern', () {
      final r = SeriesReminder(
        id: '1',
        title: 'Dienstplan',
        calendarSourceId: 'quelle-7',
        normalTriggerDay: 7,
        fallbackDay: 9,
        message: 'Dienstplan eintragen',
      );
      expect(SeriesReminder.fromJson(r.toJson()).calendarSourceId, 'quelle-7');
    });

    test('alte Erinnerungen bleiben lesbar', () {
      final alt = SeriesReminder.fromJson({
        'id': '1',
        'title': 'Dienstplan',
        'outlookCalendarId': 'AAMkAGI2',
        'normalTriggerDay': 7,
        'fallbackDay': 9,
      });
      expect(alt.title, 'Dienstplan');
      expect(alt.calendarSourceId, 'AAMkAGI2');
    });
  });
}
