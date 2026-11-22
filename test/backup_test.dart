import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/annual_event.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/place.dart';
import 'package:kalender/models/series_reminder.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/models/week_note.dart';
import 'package:kalender/models/yearly_checklist.dart';
import 'package:kalender/services/backup_service.dart';
import 'package:kalender/services/category_service.dart';
import 'package:kalender/services/local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Die App speichert auf dem Geraet. Geht das Geraet kaputt, ist alles weg —
/// es sei denn, es liegt eine Datei woanders. Die Sicherung ist diese Datei:
/// ein Stand zum Weglegen, den man ohne die App lesen kann.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await LocalService.init(db);
    CategoryService.resetForTesting();
    await CategoryService.load();
  });
  tearDown(() async => db.close());

  Future<void> bestand() async {
    await LocalService.saveEvent(CalendarEvent(
      id: 'e1',
      title: 'Besprechung',
      startTime: DateTime(2026, 11, 20, 9),
      endTime: DateTime(2026, 11, 20, 10),
      category: 'work',
    ));
    await LocalService.saveTodo(Todo(
      id: 't1',
      title: 'Tanken',
      estimatedMinutes: 15,
      createdAt: DateTime(2026, 11, 20),
      category: 'personal',
    ));
    await LocalService.saveAnnualEvent(AnnualEvent(
      id: 'a1',
      name: 'Urlaub',
      category: 'vacation',
      occurrences: [
        AnnualOccurrence(year: 2027, startDate: DateTime(2027, 6, 1)),
      ],
    ));
    await LocalService.saveReminder(SeriesReminder(
      id: 'r1',
      title: 'Müll rausstellen',
      calendarSourceId: 'cal',
      triggerEventKeyword: 'Abfuhr',
      normalTriggerDay: 2,
      fallbackCondition: 'always',
      fallbackDay: 3,
      fallbackOffsetMinutes: 0,
      windowStartHour: 18,
      windowStartMinute: 0,
      windowEndHour: 20,
      windowEndMinute: 0,
      message: 'Tonne raus',
    ));
    await LocalService.saveYearlyChecklist(YearlyChecklist(
      id: 'y1',
      title: 'Steuer',
      reminderMonth: 3,
    ));
    await LocalService.saveWeekNote(WeekNote(
      weekKey: '2026-W47',
      content: 'Ruhige Woche',
      goals: [const WeekGoal(text: 'ausschlafen', done: true)],
    ));
    await LocalService.savePlaces([
      Place(
        id: 'p1',
        name: 'McFit',
        group: 'Fitnessstudio',
        address: 'Hauptstrasse 1',
        latitude: 53.5511,
        longitude: 9.9937,
        hours: const [
          OpeningHours(weekday: 1, fromMinute: 480, toMinute: 1200),
        ],
      ),
    ]);
    await CategoryService.update('work', label: 'Dienst');
    await CategoryService.add('Ehrenamt', 0xFF00BCD4);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocking_allday_cats', ['vacation', 'work']);
    await prefs.setInt('daylight_sunrise', 7);
    await prefs.setBool('outlook_allow_todo_drop', true);
    await prefs.setString('irgendwas', 'Text');
    await prefs.setDouble('zahl', 1.5);
  }

  group('Erstellen', () {
    test('die Datei traegt alles, was dem Benutzer gehoert', () async {
      await bestand();
      final daten = jsonDecode(await BackupService.build());

      expect(daten['app'], 'kalender');
      expect(daten['format'], BackupService.formatVersion);
      expect(daten['events'], hasLength(1));
      expect(daten['todos'], hasLength(1));
      expect(daten['annualEvents'], hasLength(1));
      expect(daten['reminders'], hasLength(1));
      expect(daten['yearlyChecklists'], hasLength(1));
      expect(daten['weekNotes'], hasLength(1));
      expect(daten['categories'], hasLength(5));
      expect(daten['places'], hasLength(1));
      expect(daten['settings'], isA<Map>());
    });

    test('Geraete-Internes bleibt draussen', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('local_seeded', true);
      await prefs.setString('local_device_user_id', 'local-abc');
      await prefs.setString('eigenes', 'behalten');

      final daten = jsonDecode(await BackupService.build());
      final einstellungen = daten['settings'] as Map;

      // Die Kennung des Geraets und die Seed-Merkmale gehoeren zum Geraet,
      // nicht zum Benutzer — eingespielt wuerden sie nur Schaden anrichten.
      expect(einstellungen.containsKey('local_seeded'), isFalse);
      expect(einstellungen.containsKey('local_device_user_id'), isFalse);
      expect(einstellungen.containsKey('eigenes'), isTrue);
    });

    test('der Dateiname traegt das Datum', () {
      expect(BackupService.dateiname(DateTime(2026, 3, 7)),
          'kalender-sicherung-2026-03-07.json');
    });
  });

  group('Einspielen', () {
    test('ein Stand ueberlebt den Weg durch die Datei', () async {
      await bestand();
      final text = await BackupService.build();

      // Alles weg — wie nach einer Neuinstallation.
      await LocalService.clearAll();
      SharedPreferences.setMockInitialValues({});
      CategoryService.resetForTesting();
      expect(await LocalService.getAllEvents(), isEmpty);

      await BackupService.restore(BackupService.parse(text));

      expect((await LocalService.getAllEvents()).single.title, 'Besprechung');
      expect((await LocalService.getAllTodos()).single.title, 'Tanken');
      expect((await LocalService.getAllAnnualEvents()).single.name, 'Urlaub');
      expect((await LocalService.getReminders()).single.message, 'Tonne raus');
      expect(
          (await LocalService.getYearlyChecklists()).single.title, 'Steuer');
      final notiz = await LocalService.getWeekNote('2026-W47');
      expect(notiz.content, 'Ruhige Woche');
      expect(notiz.goals, [const WeekGoal(text: 'ausschlafen', done: true)]);

      // Orte sind Handarbeit: Zeiten abtippen macht man nicht zweimal.
      final ort = (await LocalService.getPlaces()).single;
      expect(ort.name, 'McFit');
      expect(ort.group, 'Fitnessstudio');
      expect(ort.latitude, closeTo(53.5511, 0.0001));
      expect(ort.hours.single.toMinute, 1200);
    });

    test('Kategorien kommen mit Namen und Farbe zurueck', () async {
      await bestand();
      final text = await BackupService.build();
      await LocalService.clearAll();
      CategoryService.resetForTesting();

      await BackupService.restore(BackupService.parse(text));

      expect(CategoryService.labelOf('work'), 'Dienst');
      expect(CategoryService.labelOf('ehrenamt'), 'Ehrenamt');
      expect(CategoryService.colorValueOf('ehrenamt'), 0xFF00BCD4);
    });

    test('Einstellungen behalten ihren Typ', () async {
      await bestand();
      final text = await BackupService.build();
      SharedPreferences.setMockInitialValues({});

      await BackupService.restore(BackupService.parse(text));
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getStringList('blocking_allday_cats'),
          ['vacation', 'work']);
      expect(prefs.getInt('daylight_sunrise'), 7);
      expect(prefs.getBool('outlook_allow_todo_drop'), isTrue);
      expect(prefs.getString('irgendwas'), 'Text');
      expect(prefs.getDouble('zahl'), 1.5);
    });

    test('eingespielt wird ersetzt, nicht gemischt', () async {
      await bestand();
      final text = await BackupService.build();

      await LocalService.saveEvent(CalendarEvent(
        id: 'e2',
        title: 'Kommt nach der Sicherung',
        startTime: DateTime(2026, 11, 21, 9),
        endTime: DateTime(2026, 11, 21, 10),
      ));
      expect(await LocalService.getAllEvents(), hasLength(2));

      await BackupService.restore(BackupService.parse(text));

      final events = await LocalService.getAllEvents();
      expect(events, hasLength(1));
      expect(events.single.id, 'e1');
    });
  });

  group('Fremde oder kaputte Dateien', () {
    test('kein JSON', () {
      expect(() => BackupService.parse('kein json {{{'),
          throwsA(isA<BackupFehler>()));
    });

    test('eine Datei aus einer anderen App', () {
      expect(() => BackupService.parse(jsonEncode({'app': 'etwas', 'x': 1})),
          throwsA(isA<BackupFehler>()));
    });

    test('ein neueres Format wird nicht geraten', () {
      // Lieber ehrlich verweigern als die Haelfte falsch einspielen.
      expect(
          () => BackupService.parse(jsonEncode({
                'app': 'kalender',
                'format': BackupService.formatVersion + 1,
              })),
          throwsA(isA<BackupFehler>()));
    });

    test('eine leere, aber gueltige Datei wird gelesen', () {
      final daten =
          BackupService.parse(jsonEncode({'app': 'kalender', 'format': 1}));
      final inhalt = BackupService.summarize(daten);
      expect(inhalt.zeilen, isEmpty);
    });

    test('die Zusammenfassung zaehlt, was drin ist', () async {
      await bestand();
      final inhalt =
          BackupService.summarize(BackupService.parse(await BackupService.build()));
      expect(inhalt.termine, 1);
      expect(inhalt.todos, 1);
      expect(inhalt.kategorien, 5);
      expect(inhalt.erstellt, isNotNull);
      expect(inhalt.zeilen, contains('1 Termine'));
    });
  });
}
