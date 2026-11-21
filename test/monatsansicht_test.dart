import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/services/category_service.dart';
import 'package:kalender/services/local_service.dart';
import 'package:kalender/week/month_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Die Monatsansicht zeigt ganze Wochen von Montag bis Sonntag und braucht
/// dafuer Termine aus dem ganzen sichtbaren Zeitraum — nicht nur aus einer
/// Woche, und auch die, die vor dem Monatsanfang beginnen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Monatsraster', () {
    test('faengt montags an und hoert sonntags auf', () {
      for (final monat in [
        DateTime(2026, 11),
        DateTime(2026, 2),
        DateTime(2027, 2),
        DateTime(2026, 10),
      ]) {
        final tage = monthGridDays(monat);
        expect(tage.length % 7, 0, reason: 'ganze Wochen');
        expect(tage.first.weekday, DateTime.monday);
        expect(tage.last.weekday, DateTime.sunday);
      }
    });

    test('November 2026 geht vom 26.10. bis zum 6.12.', () {
      final tage = monthGridDays(DateTime(2026, 11));
      expect(tage.length, 42);
      expect(tage.first, DateTime(2026, 10, 26));
      expect(tage.last, DateTime(2026, 12, 6));
    });

    test('ein Monat, der montags beginnt, braucht keine Randtage', () {
      // Februar 2027: Montag der 1., 28 Tage, vier Wochen genau.
      final tage = monthGridDays(DateTime(2027, 2));
      expect(tage.length, 28);
      expect(tage.first, DateTime(2027, 2, 1));
      expect(tage.last, DateTime(2027, 2, 28));
    });

    test('jeder Tag des Monats kommt genau einmal vor', () {
      final tage = monthGridDays(DateTime(2026, 11));
      final imMonat = tage.where((d) => d.month == 11 && d.year == 2026);
      expect(imMonat.length, 30);
      expect(imMonat.map((d) => d.day).toSet().length, 30);
    });

    test('die Tage laufen ohne Luecke und ohne Wiederholung', () {
      // Hier faellt auf, wenn in 24-Stunden-Schritten gerechnet wird: in der
      // Nacht der Zeitumstellung hat ein Tag 23 oder 25 Stunden, und derselbe
      // Kalendertag kaeme zweimal. Maerz und Oktober sind die Monate, in die
      // die Umstellung faellt.
      for (final monat in [DateTime(2026, 3), DateTime(2026, 10)]) {
        final tage = monthGridDays(monat);
        for (int i = 1; i < tage.length; i++) {
          expect(tage[i], addDays(tage[i - 1], 1),
              reason: 'nach ${tage[i - 1]} kommt ${tage[i]}');
        }
        expect(tage.map((d) => '${d.year}-${d.month}-${d.day}').toSet().length,
            tage.length);
      }
    });

    test('addDays bleibt auf Mitternacht und zaehlt Kalendertage', () {
      expect(addDays(DateTime(2026, 10, 25), 1), DateTime(2026, 10, 26));
      expect(addDays(DateTime(2026, 3, 29), 1), DateTime(2026, 3, 30));
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addDays(DateTime(2026, 1, 1), -1), DateTime(2025, 12, 31));
      expect(addDays(DateTime(2026, 11, 21, 14, 33), 0), DateTime(2026, 11, 21));
    });

    test('ein Monatsname fuer jeden Monat', () {
      expect(monthNames.length, 12);
      expect(monthNames[DateTime(2026, 11).month - 1], 'November');
    });
  });

  group('Farbe im Raster', () {
    CalendarEvent termin({int? kalenderfarbe, String kategorie = 'work'}) =>
        CalendarEvent(
          id: 'e',
          title: 'Termin',
          startTime: DateTime(2026, 11, 21, 9),
          endTime: DateTime(2026, 11, 21, 10),
          category: kategorie,
          calendarColor: kalenderfarbe,
        );

    test('die Farbe des Kalenders sticht die der Kategorie', () {
      expect(termin(kalenderfarbe: 0xFF00BCD4).calendarColor, 0xFF00BCD4);
      expect(monthEntryColor(termin(kalenderfarbe: 0xFF00BCD4)).toARGB32(),
          0xFF00BCD4);
    });

    test('ohne eigene Farbe entscheidet die Kategorie', () {
      final ohne = monthEntryColor(termin());
      final andere = monthEntryColor(termin(kategorie: 'vacation'));
      expect(ohne, isNot(andere));
    });
  });

  group('Zeitraum-Abfrage', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await LocalService.init(db);
      CategoryService.resetForTesting();
      await CategoryService.load();
    });
    tearDown(() async => db.close());

    Future<void> speichere(String id, DateTime start, DateTime ende) =>
        LocalService.saveEvent(CalendarEvent(
          id: id,
          title: id,
          startTime: start,
          endTime: ende,
          category: 'work',
        ));

    test('liefert, was im Zeitraum liegt', () async {
      await speichere('davor', DateTime(2026, 10, 1, 9), DateTime(2026, 10, 1, 10));
      await speichere('drin', DateTime(2026, 11, 10, 9), DateTime(2026, 11, 10, 10));
      await speichere('danach', DateTime(2026, 12, 20, 9), DateTime(2026, 12, 20, 10));

      final liste = await LocalService.eventsForRange(
              DateTime(2026, 11, 1), DateTime(2026, 12, 1))
          .first;
      expect(liste.map((e) => e.id), ['drin']);
    });

    test('ein Termin ueber den Monatswechsel steht in beiden Monaten', () async {
      // Eine Reise vom 29.11. bis zum 3.12. darf im Dezember nicht fehlen,
      // nur weil sie im November beginnt.
      await speichere('reise', DateTime(2026, 11, 29, 8), DateTime(2026, 12, 3, 18));

      final november = await LocalService.eventsForRange(
              DateTime(2026, 11, 1), DateTime(2026, 12, 1))
          .first;
      final dezember = await LocalService.eventsForRange(
              DateTime(2026, 12, 1), DateTime(2027, 1, 1))
          .first;
      expect(november.map((e) => e.id), contains('reise'));
      expect(dezember.map((e) => e.id), contains('reise'));
    });

    test('das Ende des Zeitraums gehoert nicht mehr dazu', () async {
      await speichere('grenze', DateTime(2026, 12, 1), DateTime(2026, 12, 1, 1));
      final november = await LocalService.eventsForRange(
              DateTime(2026, 11, 1), DateTime(2026, 12, 1))
          .first;
      expect(november, isEmpty);
    });

    test('sortiert nach Beginn', () async {
      await speichere('zweiter', DateTime(2026, 11, 20, 9), DateTime(2026, 11, 20, 10));
      await speichere('erster', DateTime(2026, 11, 2, 9), DateTime(2026, 11, 2, 10));
      final liste = await LocalService.eventsForRange(
              DateTime(2026, 11, 1), DateTime(2026, 12, 1))
          .first;
      expect(liste.map((e) => e.id), ['erster', 'zweiter']);
    });
  });
}
