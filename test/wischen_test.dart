import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/models/todo.dart';

/// In der Wochenansicht liegt das Wischen ueber einer Flaeche, die senkrecht
/// scrollt und in der man Eintraege lange gedrueckt haelt und zieht. Diese
/// drei Gesten duerfen sich nicht gegenseitig schlucken: senkrecht scrollen,
/// waagerecht blaettern, lange druecken zum Ziehen.
void main() {
  late List<int> geblaettert;
  late ScrollController scroll;

  Widget baue() {
    geblaettert = [];
    scroll = ScrollController();
    return MaterialApp(
      home: Scaffold(
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v.abs() < 120) return;
            geblaettert.add(v < 0 ? 1 : -1);
          },
          child: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                for (int i = 0; i < 24; i++)
                  LongPressDraggable<Todo>(
                    data: Todo(
                      id: 't$i',
                      title: 'Eintrag $i',
                      estimatedMinutes: 15,
                      createdAt: DateTime(2026, 11, 21),
                      category: 'personal',
                    ),
                    feedback: const SizedBox(
                        key: ValueKey('am-finger'), width: 40, height: 20),
                    child: SizedBox(
                      height: 80,
                      child: Center(child: Text('Eintrag $i')),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('nach links wischen blaettert vor', (tester) async {
    await tester.pumpWidget(baue());
    await tester.fling(find.text('Eintrag 2'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(geblaettert, [1]);
    expect(scroll.offset, 0, reason: 'dabei wird nicht gescrollt');
  });

  testWidgets('nach rechts wischen blaettert zurueck', (tester) async {
    await tester.pumpWidget(baue());
    await tester.fling(find.text('Eintrag 2'), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(geblaettert, [-1]);
  });

  testWidgets('senkrecht ziehen scrollt weiter wie bisher', (tester) async {
    await tester.pumpWidget(baue());
    await tester.drag(find.text('Eintrag 2'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(geblaettert, isEmpty, reason: 'kein ungewolltes Blaettern');
    expect(scroll.offset, greaterThan(0));
  });

  testWidgets('ein kurzer Wackler blaettert nicht', (tester) async {
    await tester.pumpWidget(baue());
    final start = tester.getCenter(find.text('Eintrag 2'));
    final geste = await tester.startGesture(start);
    // Langsam ein Stueck zur Seite und wieder losgelassen.
    for (int i = 0; i < 6; i++) {
      await geste.moveBy(const Offset(3, 0));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await geste.up();
    await tester.pumpAndSettle();
    expect(geblaettert, isEmpty);
  });

  testWidgets('lange gedrueckt halten zieht weiterhin den Eintrag',
      (tester) async {
    await tester.pumpWidget(baue());
    final geste =
        await tester.startGesture(tester.getCenter(find.text('Eintrag 2')));
    await tester.pump(const Duration(milliseconds: 700)); // lange gedrueckt
    await geste.moveBy(const Offset(-200, 0));
    await tester.pump();
    // Das Ziehen laeuft: der Eintrag haengt am Finger, es wird nicht
    // gleichzeitig geblaettert.
    expect(find.byKey(const ValueKey('am-finger')), findsOneWidget);
    await geste.up();
    await tester.pumpAndSettle();
    expect(geblaettert, isEmpty);
  });
}
