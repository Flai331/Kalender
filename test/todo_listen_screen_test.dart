import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/services/category_service.dart';
import 'package:kalender/services/listen_service.dart';
import 'package:kalender/services/local_service.dart';
import 'package:kalender/todos/listen_schublade.dart';
import 'package:kalender/todos/todo_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Der To-do-Bildschirm mit Listen: in der Gesamtschau steht an jeder Karte,
/// wohin sie gehoert; in einer offenen Liste steht nur noch deren Name im
/// Titel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await LocalService.init(db);
    ListenService.resetForTesting();
    await ListenService.laden();
    await CategoryService.load();
  });
  tearDown(() async => db.close());

  Future<void> lege(String titel, {String? liste}) => LocalService.saveTodo(
        Todo(
          id: titel,
          title: titel,
          createdAt: DateTime(2026, 1, 1),
          listeId: liste,
        ),
      );

  /// Baut den Bildschirm und wartet, bis der Strom geliefert hat.
  ///
  /// Bewusst ohne `pumpAndSettle`: solange der Strom noch nichts gebracht
  /// hat, dreht sich dort ein Kreisel, und `pumpAndSettle` wartet auf eine
  /// Bewegung, die nie zu Ende ist.
  Future<void> baue(WidgetTester t) async {
    await t.pumpWidget(const MaterialApp(home: TodoListScreen()));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
  }

  /// Baut den Bildschirm wieder ab und laesst drift aufraeumen.
  ///
  /// Ohne das klagt der Test „A Timer is still pending": beim Abmelden vom
  /// Datenbank-Strom setzt drift einen Zeitgeber auf null Sekunden, und der
  /// muss noch laufen duerfen, bevor der Test zu Ende ist.
  Future<void> abbauen(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(Duration.zero);
  }

  testWidgets('ohne eigene Liste steht alles unter Todos', (t) async {
    await lege('Reifen wechseln');
    await baue(t);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Reifen wechseln'), findsOneWidget);
    await abbauen(t);
  });

  testWidgets('in der Gesamtschau steht die Liste an der Karte', (t) async {
    final l = await ListenService.anlegen('Werkstatt');
    await lege('Reifen wechseln', liste: l.id);
    await lege('Milch holen');
    await baue(t);

    expect(find.text('Werkstatt'), findsOneWidget);
    expect(find.text('Aufgaben'), findsOneWidget);
    await abbauen(t);
  });

  testWidgets('eine Liste waehlen filtert und benennt den Titel', (t) async {
    final l = await ListenService.anlegen('Werkstatt');
    await lege('Reifen wechseln', liste: l.id);
    await lege('Milch holen');
    await baue(t);

    await t.tap(find.byTooltip('Open navigation menu'));
    await t.pumpAndSettle();
    await t.tap(find.text('Werkstatt').last);
    await t.pumpAndSettle();

    expect(find.text('Reifen wechseln'), findsOneWidget);
    expect(find.text('Milch holen'), findsNothing);
    // Im Titel, und an der Karte nicht mehr.
    expect(find.text('Werkstatt'), findsOneWidget);
    await abbauen(t);
  });

  testWidgets('eine leere Liste sagt, dass sie leer ist', (t) async {
    final l = await ListenService.anlegen('Werkstatt');
    await lege('Milch holen');
    await baue(t);

    await t.tap(find.byTooltip('Open navigation menu'));
    await t.pumpAndSettle();
    await t.tap(find.text('Werkstatt').last);
    await t.pumpAndSettle();

    expect(find.text('In „Werkstatt" ist nichts offen'), findsOneWidget);
    expect(ListenService.byId(l.id), isNotNull);
    await abbauen(t);
  });

  testWidgets('die Schublade zaehlt je Liste, nicht gefiltert', (t) async {
    final l = await ListenService.anlegen('Werkstatt');
    await lege('Reifen wechseln', liste: l.id);
    await lege('Milch holen');
    await lege('Brot holen');
    await baue(t);

    await t.tap(find.byTooltip('Open navigation menu'));
    await t.pumpAndSettle();

    // Alle: 3, Aufgaben: 2, Werkstatt: 1. Nur in der Schublade gesucht:
    // im Banner dahinter steht die Gesamtzahl noch einmal.
    Finder inSchublade(String text) => find.descendant(
        of: find.byType(ListenSchublade), matching: find.text(text));
    expect(inSchublade('3'), findsOneWidget);
    expect(inSchublade('2'), findsOneWidget);
    expect(inSchublade('1'), findsOneWidget);
    await abbauen(t);
  });
}
