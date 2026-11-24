import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/services/listen_service.dart';
import 'package:kalender/services/local_service.dart';
import 'package:kalender/todos/listen_schublade.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Die Schublade mit den Listen: was sie zeigt, und dass das Verwalten von
/// dort aus geht — Listen anlegen, umbenennen, einordnen, loeschen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await LocalService.init(db);
    ListenService.resetForTesting();
    await ListenService.laden();
  });
  tearDown(() async => db.close());

  /// Baut die Schublade als echte Schublade auf und zieht sie heraus.
  ///
  /// Nicht als Rumpf des Bildschirms: die Schublade schliesst sich beim
  /// Waehlen selbst, und das geht nur, wenn sie wirklich an einem Scaffold
  /// haengt.
  Future<List<String?>> baue(
    WidgetTester t, {
    String? gewaehlt,
    Map<String, int> anzahl = const {},
  }) async {
    final gewaehlte = <String?>[];
    final schluessel = GlobalKey<ScaffoldState>();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        key: schluessel,
        drawer: ListenSchublade(
          gewaehlt: gewaehlt,
          anzahl: anzahl,
          waehlen: gewaehlte.add,
        ),
        body: const SizedBox.expand(),
      ),
    ));
    schluessel.currentState!.openDrawer();
    await t.pumpAndSettle();
    return gewaehlte;
  }

  testWidgets('zeigt alles und die Standardliste', (t) async {
    await baue(t, anzahl: {ListenService.standardId: 3});
    expect(find.text('Alle To-dos'), findsOneWidget);
    expect(find.text('Aufgaben'), findsOneWidget);
    // Die Zahl steht zweimal: einmal an „Alle", einmal an der Liste.
    expect(find.text('3'), findsNWidgets(2));
  });

  testWidgets('die Zahl an „Alle" ist die Summe', (t) async {
    final l = await ListenService.anlegen('Einkauf');
    await baue(t, anzahl: {ListenService.standardId: 2, l.id: 5});
    expect(find.text('7'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('eine Liste antippen meldet sie nach draussen', (t) async {
    final l = await ListenService.anlegen('Einkauf');
    final gewaehlt = await baue(t);
    await t.tap(find.text('Einkauf'));
    await t.pumpAndSettle();
    expect(gewaehlt, [l.id]);
  });

  testWidgets('Listen in einem Ordner stehen darunter', (t) async {
    await ListenService.anlegen('Einkauf', ordner: 'Privat');
    await baue(t);
    expect(find.text('Privat'), findsOneWidget);
    expect(find.text('Einkauf'), findsOneWidget);
  });

  testWidgets('eine neue Liste wird angelegt und gleich geoeffnet',
      (t) async {
    final gewaehlt = await baue(t);
    await t.tap(find.text('Neue Liste'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Werkstatt');
    await t.tap(find.text('Anlegen'));
    await t.pumpAndSettle();

    expect(ListenService.alle.map((l) => l.name),
        ['Aufgaben', 'Werkstatt']);
    expect(gewaehlt.single, ListenService.byId(gewaehlt.single)?.id);
    expect(find.text('Werkstatt'), findsOneWidget);
  });

  testWidgets('umbenennen steht sofort in der Schublade', (t) async {
    await ListenService.anlegen('Einkauf');
    await baue(t);
    await t.tap(find.byIcon(Icons.more_vert).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Umbenennen'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Markt');
    await t.tap(find.text('Übernehmen'));
    await t.pumpAndSettle();

    expect(find.text('Markt'), findsOneWidget);
    expect(find.text('Einkauf'), findsNothing);
  });

  testWidgets('die Standardliste hat kein Löschen im Menü', (t) async {
    await baue(t);
    await t.tap(find.byIcon(Icons.more_vert).first);
    await t.pumpAndSettle();
    expect(find.text('Umbenennen'), findsOneWidget);
    expect(find.text('Löschen'), findsNothing);
  });

  testWidgets('loeschen fragt nach und nennt die Zahl der To-dos',
      (t) async {
    final l = await ListenService.anlegen('Einkauf');
    await baue(t, gewaehlt: l.id, anzahl: {l.id: 4});
    await t.tap(find.byIcon(Icons.more_vert).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Löschen'));
    await t.pumpAndSettle();

    expect(find.textContaining('Die 4 To-dos darin wandern'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Löschen'));
    await t.pumpAndSettle();
    expect(ListenService.byId(l.id), isNull);
  });

  testWidgets('in einen neuen Ordner stecken', (t) async {
    final l = await ListenService.anlegen('Einkauf');
    await baue(t);
    await t.tap(find.byIcon(Icons.more_vert).last);
    await t.pumpAndSettle();
    await t.tap(find.text('In Ordner'));
    await t.pumpAndSettle();
    await t.tap(find.text('Neuer Ordner …'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Privat');
    await t.tap(find.text('Anlegen'));
    await t.pumpAndSettle();

    expect(ListenService.byId(l.id)?.ordner, 'Privat');
    expect(find.text('Privat'), findsOneWidget);
  });
}
