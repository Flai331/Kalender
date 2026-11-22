import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/week/week_day_column.dart';

/// Beim Ziehen wird das Raster feiner, je laenger man stillhaelt:
/// 30 → 15 → 5 → 1 Minute. Zwei Dinge hatten das kaputt gemacht.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SnapState.stop);
  tearDown(SnapState.stop);

  group('Die Leiter', () {
    testWidgets('geht 30 → 15 → 5 → 1 und bleibt unten stehen', (t) async {
      expect(SnapState.current, 30);
      SnapState.resume();
      await t.pump(const Duration(milliseconds: 1600));
      expect(SnapState.current, 15);
      await t.pump(const Duration(milliseconds: 1600));
      expect(SnapState.current, 5);
      await t.pump(const Duration(milliseconds: 1600));
      expect(SnapState.current, 1);
      await t.pump(const Duration(milliseconds: 1600));
      expect(SnapState.current, 1);
    });

    testWidgets('ein neuer Zug faengt wieder grob an', (t) async {
      SnapState.resume();
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(milliseconds: 1600));
      }
      expect(SnapState.current, 1, reason: 'Leiter steht ganz unten');

      // Hier war der Fehler: ein abgebrochener Zug raeumte nicht auf. Die
      // Leiter blieb unten, der naechste Zug stand sofort am Ende und liess
      // sich nicht mehr heranzoomen — bis zum Neustart der App.
      SnapState.begin();
      expect(SnapState.current, 30);
      expect(SnapState.isDraggingNotifier.value, isFalse);

      SnapState.resume();
      await t.pump(const Duration(milliseconds: 1600));
      expect(SnapState.current, 15, reason: 'laeuft wieder los');
      SnapState.stop(); // sonst laeuft der Takt-Timer ueber das Testende
    });
  });

  group('Zitternder Finger', () {
    testWidgets('ein Pixel Wackeln zaehlt nicht als Bewegung', (t) async {
      final todo = Todo(
        id: 't1',
        title: 'Keller aufräumen',
        estimatedMinutes: 60,
        createdAt: DateTime(2026, 11, 20),
      );

      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 300,
                height: 360,
                child: WeekDayColumn(
                  day: DateTime(2026, 11, 23),
                  events: const [],
                  todos: const [],
                  isToday: true,
                  hourHeight: 60,
                  startHour: 8,
                  endHour: 14,
                  onTodoDrop: (_, __, ___, ____) {},
                  onEventDrop: (_, __, ___, ____) {},
                  onEventTap: (_) {},
                  onTodoTap: (_) {},
                  onTodoToggleDone: (_) {},
                  showHeader: false,
                ),
              ),
              SizedBox(
                height: 60,
                child: LongPressDraggable<Todo>(
                  data: todo,
                  onDragStarted: SnapState.begin,
                  onDragEnd: (_) => SnapState.stop(),
                  feedback: const Material(
                      color: Colors.transparent,
                      child: SizedBox(width: 80, height: 20)),
                  childWhenDragging: const SizedBox(width: 80, height: 20),
                  child: Container(
                    key: const Key('chip'),
                    width: 120,
                    height: 40,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));

      final chip = t.getCenter(find.byKey(const Key('chip')));
      final griff = await t.startGesture(chip);
      await t.pump(const Duration(milliseconds: 600));
      await griff.moveTo(const Offset(150, 180));
      await t.pump();

      // Vier Sekunden halten — aber mit einem Pixel Zittern alle 120 ms,
      // so wie ein echter Daumen auf Glas. Vorher blieb es dabei auf 30
      // Minuten stehen: jede Regung setzte den Ruhe-Zaehler zurueck.
      for (var i = 0; i < 33; i++) {
        await griff.moveTo(Offset(150, 180 + (i.isEven ? 1 : 0)));
        await t.pump(const Duration(milliseconds: 120));
      }

      expect(SnapState.current, lessThan(30),
          reason: 'das Raster muss trotz Zittern feiner geworden sein');

      await griff.up();
      await t.pumpAndSettle();
    });
  });
}
