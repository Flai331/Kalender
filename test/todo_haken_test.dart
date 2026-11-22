import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/services/local_service.dart';
import 'package:kalender/week/event_block.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein To-do in der Wochenansicht liess sich nur über den Status-Dialog
/// abhaken — zwei Tipper für eine Sache, die einer sein sollte. Jetzt sitzt
/// im Block selbst ein Haken.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Todo todo({
    String id = 't1',
    TodoStatus status = TodoStatus.pending,
    bool fertig = false,
    DateTime? tag,
  }) =>
      Todo(
        id: id,
        title: 'Keller aufräumen',
        estimatedMinutes: 60,
        scheduledDate: tag,
        scheduledStartHour: tag == null ? null : 9,
        status: status,
        isCompleted: fertig,
        createdAt: DateTime(2026, 11, 1),
      );

  group('Zustandswechsel', () {
    final jetzt = DateTime(2026, 11, 22, 10, 30);

    test('abhaken setzt Status, Endzeit und isCompleted', () {
      final fertig = todo().markDone(jetzt);
      expect(fertig.status, TodoStatus.done);
      expect(fertig.actualEnd, jetzt);
      expect(fertig.isCompleted, isTrue);
    });

    test('wieder aufmachen nimmt alles zurück', () {
      final zurueck = todo().markDone(jetzt).reopen();
      expect(zurueck.status, TodoStatus.pending);
      expect(zurueck.actualEnd, isNull);
      expect(zurueck.actualStart, isNull);
      // Das war der Fehler: isCompleted blieb stehen, das To-do blieb
      // damit aus der Leiste verschwunden, obwohl es wieder offen war.
      expect(zurueck.isCompleted, isFalse);
    });

    test('der Titel und die Planung bleiben unberührt', () {
      final tag = DateTime(2026, 11, 22);
      final zurueck = todo(tag: tag).markDone(jetzt).reopen();
      expect(zurueck.title, 'Keller aufräumen');
      expect(zurueck.scheduledDate, tag);
      expect(zurueck.scheduledStartHour, 9);
    });
  });

  group('Todo-Leiste', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await LocalService.init(db);
    });
    tearDown(() async => db.close());

    test('abgehakt verschwindet, wieder offen kommt zurück', () async {
      await LocalService.saveTodo(todo());
      expect(await LocalService.unscheduledTodos().first, hasLength(1));

      await LocalService.saveTodo(todo().markDone(DateTime(2026, 11, 22)));
      expect(await LocalService.unscheduledTodos().first, isEmpty);

      await LocalService.saveTodo(
          todo().markDone(DateTime(2026, 11, 22)).reopen());
      expect(await LocalService.unscheduledTodos().first, hasLength(1),
          reason: 'ein wieder geöffnetes To-do gehört zurück in die Leiste');
    });
  });

  group('Haken im Block', () {
    Future<void> zeige(WidgetTester tester, Todo t,
        {VoidCallback? onToggle, double breite = 120}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: breite,
            child: EventBlock(
                todo: t, heightPerMinute: 1.0, onToggleDone: onToggle),
          ),
        ),
      ));
    }

    testWidgets('offenes To-do zeigt einen leeren Haken', (tester) async {
      await zeige(tester, todo(), onToggle: () {});
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('erledigtes To-do zeigt den gesetzten Haken', (tester) async {
      await zeige(tester, todo(status: TodoStatus.done, fertig: true),
          onToggle: () {});
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('ein Tipp auf den Haken löst aus', (tester) async {
      var gezaehlt = 0;
      await zeige(tester, todo(), onToggle: () => gezaehlt++);

      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      expect(gezaehlt, 1);
    });

    // Eine Tagesspalte der Wochenansicht ist am Handy rund 52 px breit.
    testWidgets('schmaler Block behält den Titel, der Haken rutscht nach unten',
        (tester) async {
      await zeige(tester, todo(tag: DateTime(2026, 11, 22)),
          onToggle: () {}, breite: 52);

      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      // Der Titel muss lesbar bleiben — das war der Punkt der Uebung.
      final titel = tester.widget<Text>(find.text('Keller aufräumen'));
      expect(titel.maxLines, 2);
      // Die Uhrzeit weicht: auf 38 px ist sie ohnehin nicht zu lesen.
      expect(find.textContaining('09:00'), findsNothing);
    });

    testWidgets('breiter Block zeigt Haken und Uhrzeit nebeneinander',
        (tester) async {
      await zeige(tester, todo(tag: DateTime(2026, 11, 22)),
          onToggle: () {}, breite: 180);

      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(find.textContaining('09:00'), findsOneWidget);
    });

    testWidgets('schmal und kurz: lieber kein Haken als kein Titel',
        (tester) async {
      // 20 Minuten sind 24 px hoch. Haken und Titel passen nicht beide rein.
      final kurz = Todo(
        id: 't2',
        title: 'Müll',
        estimatedMinutes: 20,
        scheduledDate: DateTime(2026, 11, 22),
        scheduledStartHour: 9,
        createdAt: DateTime(2026, 11, 1),
      );
      await zeige(tester, kurz, onToggle: () {}, breite: 52);

      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
      expect(find.text('Müll'), findsOneWidget);
    });

    testWidgets('ohne Rückruf bleibt der Block wie vorher', (tester) async {
      // Termine haben keinen Haken: dort gibt es nichts abzuhaken.
      await zeige(tester, todo());
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });
}
