import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/widgets/travel_time_picker.dart';

/// Der ganze Sinn der Auswahl ist, drei Dinge auseinanderzuhalten:
/// „es gilt die Vorgabe" (null), „ausdruecklich keine Zeit" (0) und eine Zahl.
/// Ohne diese Unterscheidung koennte man einen Termin nicht von der
/// Kalender-Vorgabe ausnehmen.
void main() {
  Future<void> zeige(
    WidgetTester tester, {
    int? minutes,
    int? inherited,
    required void Function(int?) onChanged,
    String inheritLabel = 'Vorgabe',
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TravelTimePicker(
          label: 'Anfahrt',
          minutes: minutes,
          inherited: inherited,
          inheritLabel: inheritLabel,
          onChanged: onChanged,
        ),
      ),
    ));
  }

  testWidgets('die Vorgabe wird mit ihrem Wert angezeigt', (tester) async {
    await zeige(tester, minutes: null, inherited: 15, onChanged: (_) {});

    expect(find.text('Vorgabe (15 min)'), findsOneWidget);
    expect(find.text('Keine'), findsOneWidget,
        reason: '„keine Zeit" muss daneben waehlbar bleiben');
  });

  testWidgets('ohne geerbten Wert steht die Beschriftung allein',
      (tester) async {
    await zeige(tester, minutes: null, inherited: null, onChanged: (_) {});

    expect(find.text('Vorgabe'), findsOneWidget);
  });

  testWidgets('„Keine" meldet 0, nicht null', (tester) async {
    final gemeldet = <int?>[];
    await zeige(tester,
        minutes: null, inherited: 15, onChanged: gemeldet.add);

    await tester.tap(find.text('Keine'));
    await tester.pump();

    expect(gemeldet, [0],
        reason: '0 ist eine Aussage gegen die Vorgabe, nicht ihr Fehlen');
  });

  testWidgets('„Vorgabe" meldet null, nicht 0', (tester) async {
    final gemeldet = <int?>[];
    await zeige(tester, minutes: 30, inherited: 15, onChanged: gemeldet.add);

    await tester.tap(find.text('Vorgabe (15 min)'));
    await tester.pump();

    expect(gemeldet, [null]);
  });

  testWidgets('eine feste Zahl meldet die Zahl', (tester) async {
    final gemeldet = <int?>[];
    await zeige(tester, minutes: null, inherited: 15, onChanged: gemeldet.add);

    // Die Knopfreihe ist breiter als der Bildschirm und scrollt waagerecht —
    // die hinteren Knoepfe muessen erst hergeholt werden.
    await tester.ensureVisible(find.text('30min'));
    await tester.pump();
    await tester.tap(find.text('30min'));
    await tester.pump();

    expect(gemeldet, [30]);
  });

  testWidgets('freie Eingabe meldet die Minuten', (tester) async {
    final gemeldet = <int?>[];
    await zeige(tester, minutes: null, inherited: 15, onChanged: gemeldet.add);

    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();

    expect(gemeldet, [12]);
  });

  testWidgets('ein leeres Eingabefeld aendert nichts', (tester) async {
    final gemeldet = <int?>[];
    await zeige(tester, minutes: 12, inherited: 15, onChanged: gemeldet.add);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(gemeldet, isEmpty,
        reason: 'leer ist weder 0 noch Vorgabe — beide haben eigene Knoepfe');
  });

  testWidgets('in den Einstellungen heisst der leere Zustand anders',
      (tester) async {
    await zeige(tester,
        minutes: null,
        inherited: null,
        inheritLabel: 'Keine Vorgabe',
        onChanged: (_) {});

    expect(find.text('Keine Vorgabe'), findsOneWidget);
  });
}
