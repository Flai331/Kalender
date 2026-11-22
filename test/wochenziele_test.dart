import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/week_note.dart';
import 'package:kalender/notes/notes_screen.dart';
import 'package:kalender/services/local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vor dem Umbau stand vor jedem Wochenziel ein totes "○": es sah aus wie
/// ein Kästchen, liess sich aber nicht abhaken. Hier steht, dass der Haken
/// jetzt sitzt, sofort gespeichert wird und alte Notizen nichts verlieren.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modell', () {
    test('Altbestand stand nur als Text in der Liste', () {
      final notiz = WeekNote.fromJson({
        'weekKey': '2026-W47',
        'content': 'Ruhige Woche',
        'goals': ['ausschlafen', 'laufen gehen'],
      });
      expect(notiz.goals.map((g) => g.text), ['ausschlafen', 'laufen gehen']);
      expect(notiz.goals.every((g) => !g.done), isTrue,
          reason: 'alte Ziele waren nie abgehakt');
    });

    test('der Haken übersteht das Speichern', () {
      final notiz = WeekNote(weekKey: '2026-W47', goals: const [
        WeekGoal(text: 'ausschlafen', done: true),
        WeekGoal(text: 'laufen gehen'),
      ]);
      final zurueck = WeekNote.fromJson(notiz.toJson());
      expect(zurueck.goals.first.done, isTrue);
      expect(zurueck.goals.last.done, isFalse);
      expect(zurueck.goals.map((g) => g.text), ['ausschlafen', 'laufen gehen']);
    });

    test('gemischte Liste aus alt und neu', () {
      final notiz = WeekNote.fromJson({
        'weekKey': '2026-W47',
        'goals': [
          'alt',
          {'text': 'neu', 'done': true},
        ],
      });
      expect(notiz.goals.first, const WeekGoal(text: 'alt'));
      expect(notiz.goals.last, const WeekGoal(text: 'neu', done: true));
    });
  });

  group('Bildschirm', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await LocalService.init(db);
    });
    tearDown(() async => db.close());

    Future<String> woche() async =>
        WeekNote.keyForDate(DateTime.now());

    Future<void> oeffne(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: NotesScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('jedes Ziel hat einen Haken zum Antippen', (tester) async {
      await LocalService.saveWeekNote(WeekNote(
        weekKey: await woche(),
        goals: const [WeekGoal(text: 'ausschlafen')],
      ));
      await oeffne(tester);

      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('Antippen hakt ab und speichert sofort', (tester) async {
      final key = await woche();
      await LocalService.saveWeekNote(WeekNote(
        weekKey: key,
        goals: const [WeekGoal(text: 'ausschlafen')],
      ));
      await oeffne(tester);

      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      // Ohne "Speichern" zu druecken: der Haken steht in der Datenbank.
      final gespeichert = await LocalService.getWeekNote(key);
      expect(gespeichert.goals.single.done, isTrue);
    });

    testWidgets('nochmal antippen macht es wieder offen', (tester) async {
      final key = await woche();
      await LocalService.saveWeekNote(WeekNote(
        weekKey: key,
        goals: const [WeekGoal(text: 'ausschlafen', done: true)],
      ));
      await oeffne(tester);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pumpAndSettle();

      expect((await LocalService.getWeekNote(key)).goals.single.done, isFalse);
    });

    testWidgets('der Haken nimmt den getippten Text mit', (tester) async {
      final key = await woche();
      await LocalService.saveWeekNote(WeekNote(
        weekKey: key,
        goals: const [WeekGoal(text: 'ausschlafen')],
      ));
      await oeffne(tester);

      // Freitext tippen, aber NICHT auf Speichern druecken.
      await tester.enterText(
          find.byType(TextField).last, 'war eine gute Woche');
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();

      final gespeichert = await LocalService.getWeekNote(key);
      expect(gespeichert.content, 'war eine gute Woche',
          reason: 'ein Haken darf getippten Text nicht verwerfen');
      expect(gespeichert.goals.single.done, isTrue);
    });

    testWidgets('die Kopfzeile zählt, was noch offen ist', (tester) async {
      await LocalService.saveWeekNote(WeekNote(
        weekKey: await woche(),
        goals: const [
          WeekGoal(text: 'ausschlafen', done: true),
          WeekGoal(text: 'laufen gehen'),
          WeekGoal(text: 'Keller'),
        ],
      ));
      await oeffne(tester);

      expect(find.text('Wochenziele · 2 offen'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.radio_button_unchecked).first);
      await tester.pumpAndSettle();
      expect(find.text('Wochenziele · 1 offen'), findsOneWidget);
    });

    testWidgets('ein leeres neues Ziel wird nicht mitgespeichert',
        (tester) async {
      final key = await woche();
      await oeffne(tester);

      await tester.tap(find.text('Ziel hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();

      expect((await LocalService.getWeekNote(key)).goals, isEmpty);
    });
  });
}
