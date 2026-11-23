import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/models/vorlage.dart';
import 'package:kalender/services/local_service.dart';
import 'package:kalender/services/vorlagen_service.dart';
import 'package:kalender/widgets/vorlagen_feld.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Das Titelfeld, das die Vorlagen kennt: getippt wird einhaendig und
/// unterwegs, darum muss der Vorschlag auch bei „diesn" noch stehen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await LocalService.init(db);
    VorlagenService.resetForTesting();
  });
  tearDown(() async => db.close());

  Future<void> merkeDienst() => VorlagenService.ausTermin(CalendarEvent(
        id: 'e1',
        title: 'Dienst Spät',
        startTime: DateTime(2026, 3, 2, 14, 0),
        endTime: DateTime(2026, 3, 2, 22, 0),
        category: 'work',
        travelBeforeOverride: 20,
        travelAfterOverride: 10,
      ));

  /// Baut das Feld und gibt zurueck, was gewaehlt wurde.
  Future<(TextEditingController, List<Vorlage>)> baue(
      WidgetTester t, Vorlagenart art) async {
    final ctrl = TextEditingController();
    final genommen = <Vorlage>[];
    addTearDown(ctrl.dispose);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: VorlagenFeld(
            controller: ctrl,
            art: art,
            label: 'Titel',
            hint: 'Termintitel...',
            gewaehlt: genommen.add,
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();
    return (ctrl, genommen);
  }

  testWidgets('der Vorschlag erscheint beim Tippen', (t) async {
    await merkeDienst();
    await baue(t, Vorlagenart.termin);

    expect(find.text('Dienst Spät'), findsNothing);
    await t.enterText(find.byType(TextField), 'die');
    await t.pumpAndSettle();
    expect(find.text('Dienst Spät'), findsOneWidget);
  });

  testWidgets('auch bei einem Tippfehler', (t) async {
    await merkeDienst();
    await baue(t, Vorlagenart.termin);

    await t.enterText(find.byType(TextField), 'diesnt');
    await t.pumpAndSettle();
    expect(find.text('Dienst Spät'), findsOneWidget);
  });

  testWidgets('die Unterzeile sagt, was drinsteht', (t) async {
    await merkeDienst();
    await baue(t, Vorlagenart.termin);

    await t.enterText(find.byType(TextField), 'die');
    await t.pumpAndSettle();
    expect(find.textContaining('8 Std'), findsOneWidget);
    expect(find.textContaining('20/10 Min Fahrt'), findsOneWidget);
  });

  testWidgets('was gar nicht passt, erscheint nicht', (t) async {
    await merkeDienst();
    await baue(t, Vorlagenart.termin);

    await t.enterText(find.byType(TextField), 'Zahnarzt');
    await t.pumpAndSettle();
    expect(find.text('Dienst Spät'), findsNothing);
  });

  testWidgets('To-do-Vorlagen erscheinen nicht am Termin-Feld', (t) async {
    await VorlagenService.ausTodo(Todo(
      id: 't1',
      title: 'Dienst Spät',
      createdAt: DateTime(2026, 1, 1),
    ));
    await baue(t, Vorlagenart.termin);

    await t.enterText(find.byType(TextField), 'die');
    await t.pumpAndSettle();
    expect(find.text('Dienst Spät'), findsNothing);
  });

  testWidgets('Antippen setzt den Titel und meldet die Vorlage', (t) async {
    await merkeDienst();
    final (ctrl, genommen) = await baue(t, Vorlagenart.termin);

    await t.enterText(find.byType(TextField), 'diesn');
    await t.pumpAndSettle();
    await t.tap(find.text('Dienst Spät'));
    await t.pumpAndSettle();

    expect(ctrl.text, 'Dienst Spät');
    expect(genommen.length, 1);
    expect(genommen.first.felder['travelBeforeOverride'], 20);
    // Danach ist die Liste weg — sonst verdeckte sie das halbe Formular.
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('Benutzen wird gezaehlt', (t) async {
    await merkeDienst();
    await baue(t, Vorlagenart.termin);

    await t.enterText(find.byType(TextField), 'die');
    await t.pumpAndSettle();
    await t.tap(find.text('Dienst Spät'));
    await t.pumpAndSettle();

    final alle = await VorlagenService.fuer(Vorlagenart.termin);
    expect(alle.first.benutzt, 1);
  });

  testWidgets('eine neu gemerkte Vorlage wird sofort vorgeschlagen',
      (t) async {
    await baue(t, Vorlagenart.termin);

    await t.enterText(find.byType(TextField), 'die');
    await t.pumpAndSettle();
    expect(find.text('Dienst Spät'), findsNothing);

    // Waehrend das Feld offen steht, wird woanders eine Vorlage gemerkt.
    await merkeDienst();
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'dien');
    await t.pumpAndSettle();
    expect(find.text('Dienst Spät'), findsOneWidget);
  });
}
