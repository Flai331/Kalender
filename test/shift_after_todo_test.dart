import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/services/local_service.dart';
import 'package:kalender/services/shift_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gemeldet: „Ein To-do, das ich angelegt und im Kalender gespeichert habe,
/// wurde nicht mit verschoben."
///
/// Der Auto-Shift legt Todos lueckenlos hintereinander (siehe
/// _autoShiftOverdueTodos: runningMin = Ende des vorigen Blocks). Das direkt
/// folgende To-do beginnt damit GENAU zur Soll-Endzeit des vorigen — und genau
/// dieser Fall fiel durch: verschoben wurde nur, was spaeter begann.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final tag = DateTime(2026, 11, 18);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await LocalService.init(db);
  });
  tearDown(() async => db.close());

  Todo todo(String id, int hour, int minute,
          {int dauer = 30, bool fix = false}) =>
      Todo(
        id: id,
        title: id,
        estimatedMinutes: dauer,
        scheduledDate: tag,
        scheduledStartHour: hour,
        scheduledStartMinute: minute,
        isFixed: fix,
        createdAt: tag,
      );

  Future<String> startzeit(String id) async {
    final t = await LocalService.getTodoById(id);
    return '${t!.scheduledStartHour}:'
        '${(t.scheduledStartMinute ?? 0).toString().padLeft(2, '0')}';
  }

  test('das direkt anschliessende To-do wird mitverschoben', () async {
    // 10:00 + 30 min -> Soll-Ende 10:30
    final fertig = todo('A', 10, 0);
    await LocalService.saveTodo(fertig);
    await LocalService.saveTodo(todo('B', 10, 30)); // genau am Soll-Ende
    await LocalService.saveTodo(todo('C', 11, 0));

    // 15 Minuten frueher fertig
    await ShiftService.shiftAfterTodo(
        completedTodo: fertig, deltaMinutes: -15);

    expect(await startzeit('B'), '10:15',
        reason: 'beginnt genau zur Soll-Endzeit und muss mitwandern');
    expect(await startzeit('C'), '10:45');
  });

  test('zu spaet fertig: dasselbe nach hinten', () async {
    final fertig = todo('A', 10, 0);
    await LocalService.saveTodo(fertig);
    await LocalService.saveTodo(todo('B', 10, 30));

    await ShiftService.shiftAfterTodo(completedTodo: fertig, deltaMinutes: 20);

    expect(await startzeit('B'), '10:50');
  });

  test('das fertige To-do selbst bleibt liegen', () async {
    // Dauer 0: Soll-Ende == Startzeit. Ohne eigene Pruefung wuerde sich das
    // gerade abgeschlossene To-do selbst verschieben.
    final fertig = todo('A', 10, 0, dauer: 0);
    await LocalService.saveTodo(fertig);

    await ShiftService.shiftAfterTodo(completedTodo: fertig, deltaMinutes: 20);

    expect(await startzeit('A'), '10:00');
  });

  test('festes To-do bleibt stehen', () async {
    final fertig = todo('A', 10, 0);
    await LocalService.saveTodo(fertig);
    await LocalService.saveTodo(todo('B', 10, 30, fix: true));

    await ShiftService.shiftAfterTodo(completedTodo: fertig, deltaMinutes: 20);

    expect(await startzeit('B'), '10:30');
  });

  test('frueheres To-do bleibt unberuehrt', () async {
    final fertig = todo('A', 10, 0);
    await LocalService.saveTodo(fertig);
    await LocalService.saveTodo(todo('F', 9, 0));

    await ShiftService.shiftAfterTodo(completedTodo: fertig, deltaMinutes: 20);

    expect(await startzeit('F'), '9:00');
  });
}
