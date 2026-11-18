import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/services/local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein ueberfaelliges To-do wird jede Minute neu auf "jetzt" geschrieben.
/// Vorher legte jeder dieser Schreibvorgaenge einen eigenen Sync-Auftrag an:
/// sechzig Zeilen und sechzig Supabase-Aufrufe pro Stunde, alle mit demselben
/// Datensatz. Die Schlange fasst jetzt je Eintrag zusammen.
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

  Todo todo(String id, {String titel = 'Aufgabe', int stunde = 9}) => Todo(
        id: id,
        title: titel,
        estimatedMinutes: 30,
        scheduledDate: tag,
        scheduledStartHour: stunde,
        scheduledStartMinute: 0,
        createdAt: tag,
      );

  test('dasselbe To-do mehrfach speichern ergibt einen Auftrag', () async {
    for (var stunde = 9; stunde < 15; stunde++) {
      await LocalService.saveTodo(todo('t1', stunde: stunde));
    }

    final queue = await LocalService.getPendingQueue();
    expect(queue.length, 1);

    // Und zwar der neueste Stand, nicht der erste.
    final payload = jsonDecode(queue.single.payload) as Map<String, dynamic>;
    expect(payload['scheduledStartHour'], 14);
  });

  test('verschiedene To-dos bleiben getrennt', () async {
    await LocalService.saveTodo(todo('t1'));
    await LocalService.saveTodo(todo('t2'));
    await LocalService.saveTodo(todo('t1', titel: 'geaendert'));

    final queue = await LocalService.getPendingQueue();
    expect(queue.length, 2);
    expect(queue.map((q) => q.entityId).toSet(), {'t1', 't2'});
  });

  test('gleiche Kennung in verschiedenen Tabellen bleibt getrennt', () async {
    await LocalService.saveTodo(todo('x1'));
    await LocalService.saveEvent(CalendarEvent(
      id: 'x1',
      title: 'Termin',
      startTime: DateTime(2026, 11, 18, 9),
      endTime: DateTime(2026, 11, 18, 10),
    ));

    final queue = await LocalService.getPendingQueue();
    expect(queue.length, 2);
    expect(queue.map((q) => q.targetTable).toSet(),
        {'todos', 'calendar_events'});
  });

  test('ein Loeschen raeumt die offenen Speicher-Auftraege ab', () async {
    await LocalService.saveTodo(todo('t1'));
    await LocalService.saveTodo(todo('t1', titel: 'geaendert'));
    await LocalService.deleteTodo('t1');

    final queue = await LocalService.getPendingQueue();
    expect(queue.length, 1);
    expect(queue.single.operation, 'delete');
  });

  test('ein Speichern nach dem Loeschen laesst das Loeschen stehen', () async {
    // Sonst kippte die Reihenfolge: erst anlegen, dann loeschen — und der
    // Eintrag waere auf dem Server weg, obwohl er lokal existiert.
    await LocalService.deleteTodo('t1');
    await LocalService.saveTodo(todo('t1'));

    final queue = await LocalService.getPendingQueue();
    expect(queue.length, 2);
    expect(queue.first.operation, 'delete');
    expect(queue.last.operation, 'upsert');
  });

  test('zwei Loeschungen desselben Eintrags ergeben eine', () async {
    await LocalService.deleteTodo('t1');
    await LocalService.deleteTodo('t1');

    final queue = await LocalService.getPendingQueue();
    expect(queue.length, 1);
  });

  test('die Schlange bleibt chronologisch', () async {
    await LocalService.saveTodo(todo('t1'));
    await LocalService.saveTodo(todo('t2'));
    final queue = await LocalService.getPendingQueue();
    expect(queue.map((q) => q.entityId).toList(), ['t1', 't2']);
  });
}
