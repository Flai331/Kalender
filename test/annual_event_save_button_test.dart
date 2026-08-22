import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/yearly/annual_event_edit_screen.dart';

/// Regressionstest zum Fehlerbericht vom 22.08.2026:
/// "ich kann keinen Jahresplan speichern habe es für 27 versucht und der
///  Speicherknopf hat keine Funktion"
///
/// Im Test ist weder Supabase noch die lokale DB initialisiert, das Speichern
/// wirft also — genau wie auf dem Gerät ohne Netz. Geprüft wird, dass der
/// Knopf danach weiter bedienbar bleibt und der Fehler sichtbar wird.
void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AnnualEventEditScreen(initialYear: 2027),
    ));
  }

  testWidgets('Speichern bleibt nach einem Fehler bedienbar', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).first, 'Urlaub Teneriffa');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    // Vor dem Fix blieb _saving dauerhaft true: der Knopf war durch den
    // Spinner ersetzt und jeder weitere Tipp lief ins Leere.
    expect(find.text('Speichern'), findsOneWidget,
        reason: 'Speichern-Knopf muss nach einem Fehler zurückkommen');
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Der Fehler wird gemeldet statt still verschluckt.
    expect(find.byType(SnackBar), findsOneWidget);

    // Erste Meldung ablaufen lassen.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    // Zweiter Versuch muss wieder etwas auslösen — vor dem Fix passierte
    // hier gar nichts mehr.
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget,
        reason: 'zweiter Tipp muss den Speichervorgang erneut starten');
  });

  testWidgets('leerer Name gibt eine sichtbare Rückmeldung', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Speichern'));
    await tester.pump();

    expect(find.text('Bitte einen Namen eingeben.'), findsOneWidget);
  });
}
