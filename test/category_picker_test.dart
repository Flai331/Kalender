import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/services/category_service.dart';
import 'package:kalender/widgets/category_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gemeldet an der Jahres-Event-Maske: die Kategorien standen dort als
/// „personal", „work", „sport", „vacation" — der Schluessel aus der Datenbank,
/// nicht der Name. Die Auswahl zeigt jetzt den Namen und meldet den
/// Schluessel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CategoryService.resetForTesting();
    await CategoryService.load();
  });

  Future<void> zeige(
    WidgetTester tester, {
    required String? selected,
    required void Function(String?) onChanged,
    bool allowNone = false,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CategoryPicker(
          selected: selected,
          onChanged: onChanged,
          allowNone: allowNone,
        ),
      ),
    ));
  }

  testWidgets('angezeigt wird der Name, nicht der Schluessel', (tester) async {
    await zeige(tester, selected: 'personal', onChanged: (_) {});

    expect(find.text('Persönlich'), findsOneWidget);
    expect(find.text('Arbeit'), findsOneWidget);
    expect(find.text('Urlaub'), findsOneWidget);
    expect(find.text('personal'), findsNothing);
    expect(find.text('work'), findsNothing);
  });

  testWidgets('gemeldet wird der Schluessel, nicht der Name', (tester) async {
    String? gemeldet;
    await zeige(tester,
        selected: 'personal', onChanged: (c) => gemeldet = c);

    await tester.tap(find.text('Arbeit'));
    expect(gemeldet, 'work');
  });

  testWidgets('ein eigener Name erscheint in der Auswahl', (tester) async {
    await CategoryService.update('work', label: 'Dienst');
    await CategoryService.add('Ehrenamt', 0xFF00BCD4);

    String? gemeldet;
    await zeige(tester, selected: 'personal', onChanged: (c) => gemeldet = c);

    expect(find.text('Dienst'), findsOneWidget);
    expect(find.text('Arbeit'), findsNothing);

    await tester.tap(find.text('Ehrenamt'));
    // Der Schluessel bleibt, was er beim Anlegen war.
    expect(gemeldet, 'ehrenamt');
  });

  testWidgets('eine geloeschte Kategorie bleibt am Eintrag sichtbar',
      (tester) async {
    await CategoryService.remove('sport');

    await zeige(tester, selected: 'sport', onChanged: (_) {});

    // Wuerde sie fehlen, taeuschte der Bildschirm eine andere Kategorie vor
    // und das blosse Oeffnen wuerde den Eintrag umhaengen.
    expect(find.text('sport'), findsOneWidget);
  });

  testWidgets('ohne allowNone bleibt eine Auswahl bestehen', (tester) async {
    String? gemeldet = 'nicht gerufen';
    await zeige(tester, selected: 'work', onChanged: (c) => gemeldet = c);

    await tester.tap(find.text('Arbeit'));
    expect(gemeldet, 'work', reason: 'ein Termin braucht eine Kategorie');
  });

  testWidgets('mit allowNone hebt ein zweiter Tipp die Auswahl auf',
      (tester) async {
    String? gemeldet = 'nicht gerufen';
    await zeige(tester,
        selected: 'work', allowNone: true, onChanged: (c) => gemeldet = c);

    await tester.tap(find.text('Arbeit'));
    expect(gemeldet, isNull,
        reason: 'die Bedingung „nur waehrend X" muss abwaehlbar sein');
  });

  testWidgets('eine umbenannte Kategorie wird sofort neu gezeichnet',
      (tester) async {
    await zeige(tester, selected: 'work', onChanged: (_) {});
    expect(find.text('Arbeit'), findsOneWidget);

    await CategoryService.update('work', label: 'Dienst');
    await tester.pump();

    expect(find.text('Dienst'), findsOneWidget);
    expect(find.text('Arbeit'), findsNothing);
  });
}
