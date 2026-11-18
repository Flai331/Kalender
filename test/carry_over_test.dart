import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/services/local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Der Auto-Shift sieht nur den heutigen Tag an. Um Mitternacht ist ein
/// unerledigtes To-do nicht mehr "heute" — es blieb damit fuer immer in der
/// Vergangenheit liegen. getOpenTodosBefore sammelt ein, was nachzuholen ist.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final heute = DateTime(2026, 11, 18);
  final gestern = DateTime(2026, 11, 17);
  final vorgestern = DateTime(2026, 11, 16);
  final morgen = DateTime(2026, 11, 19);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await LocalService.init(db);
  });
  tearDown(() async => db.close());

  Future<void> lege(
    String id, {
    required DateTime? tag,
    int? stunde = 9,
    bool fest = false,
    bool erledigt = false,
    TodoStatus status = TodoStatus.pending,
  }) =>
      LocalService.saveTodo(Todo(
        id: id,
        title: id,
        estimatedMinutes: 30,
        scheduledDate: tag,
        scheduledStartHour: stunde,
        scheduledStartMinute: 0,
        isFixed: fest,
        isCompleted: erledigt,
        status: status,
        createdAt: vorgestern,
      ));

  Future<List<String>> offenVor(DateTime tag) async =>
      (await LocalService.getOpenTodosBefore(tag)).map((t) => t.id).toList();

  test('ein offenes To-do von gestern wird nachgeholt', () async {
    await lege('gestern', tag: gestern);
    expect(await offenVor(heute), ['gestern']);
  });

  test('erledigte bleiben liegen, wo sie waren', () async {
    await lege('abgehakt', tag: gestern, erledigt: true);
    await lege('fertig', tag: gestern, status: TodoStatus.done);
    expect(await offenVor(heute), isEmpty);
  });

  test('begonnene und pausierte werden mitgenommen', () async {
    await lege('begonnen', tag: gestern, status: TodoStatus.started);
    await lege('pausiert', tag: gestern, status: TodoStatus.paused);
    expect((await offenVor(heute)).length, 2);
  });

  test('feste To-dos bleiben stehen', () async {
    // "Fest" heisst, dass die App sie nicht verschiebt — auch nicht hierhin.
    await lege('fest', tag: gestern, fest: true);
    expect(await offenVor(heute), isEmpty);
  });

  test('heute und morgen werden nicht angefasst', () async {
    await lege('heute', tag: heute);
    await lege('morgen', tag: morgen);
    expect(await offenVor(heute), isEmpty);
  });

  test('ein To-do ganz ohne Termin bleibt ungeplant', () async {
    await lege('ohne', tag: null, stunde: null);
    expect(await offenVor(heute), isEmpty);
  });

  test('ein To-do ohne Uhrzeit wird trotzdem nachgeholt', () async {
    await lege('ohne Uhrzeit', tag: gestern, stunde: null);
    expect(await offenVor(heute), ['ohne Uhrzeit']);
  });

  test('sortiert nach Tag, dann nach Uhrzeit', () async {
    await lege('gestern spaet', tag: gestern, stunde: 18);
    await lege('vorgestern', tag: vorgestern, stunde: 12);
    await lege('gestern frueh', tag: gestern, stunde: 7);
    expect(await offenVor(heute),
        ['vorgestern', 'gestern frueh', 'gestern spaet']);
  });

  test('die Uhrzeit bleibt beim Nachholen erhalten', () async {
    await lege('termin', tag: gestern, stunde: 14);
    final todo = (await LocalService.getOpenTodosBefore(heute)).single;
    await LocalService.saveTodo(todo.copyWith(scheduledDate: heute));

    final heutige = await LocalService.getTodosForDate(heute);
    expect(heutige.single.scheduledStartHour, 14);
    // Und danach ist nichts mehr nachzuholen.
    expect(await offenVor(heute), isEmpty);
  });
}
