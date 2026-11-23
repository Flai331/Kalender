import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/ics_source.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/services/category_service.dart';
import 'package:kalender/services/local_service.dart';
import 'package:kalender/todos/todo_edit_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein To-do an einen Kalender binden: „die Abrechnung nur im Dienst".
///
/// Die Auswahl steht im To-do-Bildschirm unter dem Planungskontext — und nur
/// dort, wo sie etwas bewirkt. Bei „Ueberall" waere sie eine Luege.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  final abos = [
    const IcsSource(
        id: 'abo-dienstplan', name: 'Dienstplan', url: 'https://x/d.ics'),
    const IcsSource(
        id: 'abo-mama',
        name: 'Dienst Mama',
        url: 'https://x/m.ics',
        infoOnly: true),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'ics_sources': IcsSource.listToJson(abos)});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await LocalService.init(db);
    CategoryService.resetForTesting();
    await CategoryService.load();
  });
  tearDown(() async => db.close());

  /// Der Bildschirm ist eine lange Liste. Im Standard-Fenster von 800x600
  /// baut Flutter nur, was sichtbar ist — der Planungskontext liegt weit
  /// darunter und existierte im Test gar nicht. Darum ein hohes Fenster,
  /// statt in jedem Test zu scrollen.
  Future<void> zeige(WidgetTester t, {Todo? todo}) async {
    t.view.physicalSize = const Size(900, 4000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: TodoEditScreen(todo: todo)));
    await t.pumpAndSettle();
  }

  Todo todo({String? kalender, TodoContextMode? modus}) => Todo(
        id: 't1',
        title: 'Abrechnung',
        estimatedMinutes: 30,
        contextMode: modus ?? TodoContextMode.categoryEvent,
        requiredCalendarId: kalender,
        createdAt: DateTime(2026, 11, 20),
      );

  const frage = 'Nur in Terminen aus diesem Kalender';

  group('Wo die Auswahl steht', () {
    testWidgets('bei „Ueberall" gar nicht', (t) async {
      await zeige(t, todo: todo(modus: TodoContextMode.anyTime));
      expect(find.text(frage), findsNothing);
    });

    testWidgets('bei „Im Termin" mit allen Kalendern', (t) async {
      await zeige(t, todo: todo());
      expect(find.text(frage), findsOneWidget);
      expect(find.text('Alle Kalender'), findsOneWidget);
      expect(find.text('Eigene Termine'), findsOneWidget);
      expect(find.text('Dienstplan'), findsOneWidget);
      expect(find.text('Dienst Mama'), findsOneWidget,
          reason: 'auch ein Kalender nur zur Kenntnis ist waehlbar — '
              '„waehrend sie arbeitet" ist eine zulaessige Ansage');
    });

    testWidgets('sie kommt, wenn man den Modus umstellt', (t) async {
      await zeige(t, todo: todo(modus: TodoContextMode.anyTime));
      await t.tap(find.text('Gelegenheit'));
      await t.pumpAndSettle();
      expect(find.text(frage), findsOneWidget);
    });
  });

  group('Was die Auswahl speichert', () {
    testWidgets('der getippte Kalender landet am To-do', (t) async {
      await zeige(t, todo: todo());
      await t.tap(find.text('Dienstplan'));
      await t.pumpAndSettle();

      await t.tap(find.text('Speichern'));
      await t.pumpAndSettle();

      final gespeichert = await LocalService.getTodoById('t1');
      expect(gespeichert?.requiredCalendarId, 'abo-dienstplan');
    });

    testWidgets('„Alle Kalender" nimmt die Bindung wieder weg', (t) async {
      await zeige(t, todo: todo(kalender: 'abo-dienstplan'));
      await t.tap(find.text('Alle Kalender'));
      await t.pumpAndSettle();
      await t.tap(find.text('Speichern'));
      await t.pumpAndSettle();

      final gespeichert = await LocalService.getTodoById('t1');
      expect(gespeichert?.requiredCalendarId, isNull);
    });

    testWidgets('ein anderer Planungsmodus loest die Bindung', (t) async {
      // Sonst stuende am To-do eine Bedingung, die niemand mehr sieht.
      await zeige(t, todo: todo(kalender: 'abo-dienstplan'));
      await t.tap(find.text('Überall'));
      await t.pumpAndSettle();
      await t.tap(find.text('Speichern'));
      await t.pumpAndSettle();

      final gespeichert = await LocalService.getTodoById('t1');
      expect(gespeichert?.requiredCalendarId, isNull);
      expect(gespeichert?.contextMode, TodoContextMode.anyTime);
    });
  });

  group('Ein ausgeblendeter Kalender', () {
    testWidgets('wird als Sackgasse benannt', (t) async {
      // Ausgeblendete Abos werden nicht geholt. Ohne Hinweis sucht man den
      // Fehler beim Planen statt bei der Sichtbarkeit.
      SharedPreferences.setMockInitialValues({
        'ics_sources': IcsSource.listToJson([
          const IcsSource(
              id: 'abo-aus',
              name: 'Altes Abo',
              url: 'https://x/a.ics',
              visible: false),
        ])
      });
      await zeige(t, todo: todo(kalender: 'abo-aus'));
      expect(
          find.textContaining('ausgeblendet und liefert keine'), findsOneWidget);
    });

    testWidgets('ein sichtbarer nicht', (t) async {
      await zeige(t, todo: todo(kalender: 'abo-dienstplan'));
      expect(find.textContaining('ausgeblendet'), findsNothing);
    });
  });
}
