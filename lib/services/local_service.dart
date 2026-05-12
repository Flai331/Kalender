import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../models/calendar_event.dart';
import '../models/todo.dart';
import 'auth_service.dart';

class LocalService {
  static late AppDatabase _db;

  static void init(AppDatabase db) => _db = db;

  // ── CalendarEvents ────────────────────────────────────────────────────────

  static Stream<List<CalendarEvent>> eventsForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return (_db.select(_db.eventsCache)
          ..where((e) => e.userId.equals(_uid)))
        .watch()
        .map((rows) => rows
            .map((r) => CalendarEvent.fromJson(
                jsonDecode(r.data) as Map<String, dynamic>))
            .where((e) =>
                !e.startTime.isBefore(weekStart) &&
                e.startTime.isBefore(weekEnd))
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime)));
  }

  static Future<void> saveEvent(CalendarEvent event) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.eventsCache).insertOnConflictUpdate(
          EventsCacheCompanion(
            id: Value(event.id),
            userId: Value(_uid),
            data: Value(jsonEncode(event.toJson())),
            updatedAt: Value(now),
          ),
        );
    await _enqueue('calendar_events', 'upsert', event.id, event.toJson());
  }

  static Future<void> deleteEvent(String id) async {
    await (_db.delete(_db.eventsCache)
          ..where((e) => e.id.equals(id)))
        .go();
    await _enqueue('calendar_events', 'delete', id, {'id': id});
  }

  // ── Todos ────────────────────────────────────────────────────────────────

  static Stream<List<Todo>> unscheduledTodos() {
    return (_db.select(_db.todosCache)
          ..where((t) => t.userId.equals(_uid)))
        .watch()
        .map((rows) => rows
            .map((r) =>
                Todo.fromJson(jsonDecode(r.data) as Map<String, dynamic>))
            .where((t) => t.scheduledDate == null && !t.isCompleted)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
  }

  static Stream<List<Todo>> todosForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return (_db.select(_db.todosCache)
          ..where((t) => t.userId.equals(_uid)))
        .watch()
        .map((rows) => rows
            .map((r) =>
                Todo.fromJson(jsonDecode(r.data) as Map<String, dynamic>))
            .where((t) =>
                t.scheduledDate != null &&
                !t.scheduledDate!.isBefore(weekStart) &&
                t.scheduledDate!.isBefore(weekEnd))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
  }

  static Future<void> saveTodo(Todo todo) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.todosCache).insertOnConflictUpdate(
          TodosCacheCompanion(
            id: Value(todo.id),
            userId: Value(_uid),
            data: Value(jsonEncode(todo.toJson())),
            updatedAt: Value(now),
          ),
        );
    await _enqueue('todos', 'upsert', todo.id, todo.toJson());
  }

  static Future<void> deleteTodo(String id) async {
    await (_db.delete(_db.todosCache)..where((t) => t.id.equals(id))).go();
    await _enqueue('todos', 'delete', id, {'id': id});
  }

  // ── Sync queue ────────────────────────────────────────────────────────────

  static Future<void> _enqueue(
      String table, String operation, String entityId, Map<String, dynamic> payload) async {
    await _db.into(_db.syncQueue).insert(SyncQueueCompanion(
          entityId: Value(entityId),
          targetTable: Value(table), // NOTE: targetTable, not tableName
          operation: Value(operation),
          payload: Value(jsonEncode(payload)),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  static Future<List<SyncQueueData>> getPendingQueue() =>
      (_db.select(_db.syncQueue)
            ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
          .get();

  static Future<void> removeFromQueue(int id) =>
      (_db.delete(_db.syncQueue)..where((q) => q.id.equals(id))).go();

  /// Seed local cache from Supabase rows (called on first launch / full refresh).
  static Future<void> seedEvents(List<CalendarEvent> events) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final e in events) {
        batch.insert(
          _db.eventsCache,
          EventsCacheCompanion(
            id: Value(e.id),
            userId: Value(_uid),
            data: Value(jsonEncode(e.toJson())),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  static Future<void> seedTodos(List<Todo> todos) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final t in todos) {
        batch.insert(
          _db.todosCache,
          TodosCacheCompanion(
            id: Value(t.id),
            userId: Value(_uid),
            data: Value(jsonEncode(t.toJson())),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  static String get _uid {
    try {
      return AuthService.userId ?? '';
    } catch (_) {
      return '';
    }
  }
}
