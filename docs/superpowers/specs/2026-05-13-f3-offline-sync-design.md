# F3: Offline-Sync

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App works fully offline. All reads/writes go to local SQLite DB. A sync engine processes a change queue when internet is available. Conflicts (local change + newer server version) show a user-facing dialog.

**Architecture:** `drift` (SQLite) as local mirror. `LocalService` wraps all data access — reads from local DB, writes to local + adds to `SyncQueue`. `SyncService` listens to `connectivity_plus` and drains the queue. `SupabaseService` becomes a pure transport layer (not called by UI). Conflict detection: compare `updatedAt` timestamps.

**Tech Stack:** Flutter, `drift` ^2.x, `connectivity_plus` ^6.x, `sqlite3_flutter_libs`, Supabase (existing)

---

## Files

- Modify: `pubspec.yaml` — add drift, connectivity_plus, sqlite3_flutter_libs, build_runner, drift_dev
- Create: `lib/db/app_database.dart` — drift DB with cached tables + sync queue
- Create: `lib/db/sync_queue_entry.dart` — queue entry model
- Create: `lib/services/local_service.dart` — unified read/write API
- Create: `lib/services/sync_service.dart` — sync engine
- Create: `lib/widgets/conflict_dialog.dart` — conflict resolution UI
- Modify: `lib/main.dart` — init DB + SyncService
- Modify: all screens — swap `SupabaseService` calls → `LocalService`

---

## Data Model

### SyncQueue table (drift)
| column | type | notes |
|--------|------|-------|
| id | int (auto) | primary key |
| entityId | text | UUID of the entity |
| tableName | text | 'calendar_events' / 'todos' |
| operation | text | 'upsert' / 'delete' |
| payload | text | JSON |
| createdAt | int | epoch ms |

### Local cache tables
- `events_cache`: id (text PK), userId (text), data (text JSON), updatedAt (int epoch ms)
- `todos_cache`: same schema

---

## Task 1: Dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependencies**

Under `dependencies:`:
```yaml
drift: ^2.20.0
sqlite3_flutter_libs: ^0.5.0
connectivity_plus: ^6.0.0
path_provider: ^2.1.0  # likely already present
```

Under `dev_dependencies:`:
```yaml
drift_dev: ^2.20.0
build_runner: ^2.4.0
```

- [ ] **Step 2: Install**

```
flutter pub get
```

- [ ] **Step 3: Commit**

```
git add pubspec.yaml pubspec.lock
git commit -m "feat: add drift, connectivity_plus for offline sync"
```

---

## Task 2: Drift database

**Files:**
- Create: `lib/db/app_database.dart`

- [ ] **Step 1: Create drift DB**

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class EventsCache extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get data => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class TodosCache extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get data => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text()();
  TextColumn get tableName => text()();
  TextColumn get operation => text()(); // 'upsert' | 'delete'
  TextColumn get payload => text()();
  IntColumn get createdAt => integer()();
}

@DriftDatabase(tables: [EventsCache, TodosCache, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'kalender.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
```

- [ ] **Step 2: Generate drift code**

```
dart run build_runner build --delete-conflicting-outputs
```
Expected: `app_database.g.dart` generated.

- [ ] **Step 3: Commit**

```
git add lib/db/
git commit -m "feat: add drift AppDatabase with cache and sync queue tables"
```

---

## Task 3: LocalService

**Files:**
- Create: `lib/services/local_service.dart`

- [ ] **Step 1: Create LocalService**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../models/calendar_event.dart';
import '../models/todo.dart';

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
          tableName: Value(table),
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
    // same pattern as SupabaseService
    try {
      return AuthService.userId ?? '';
    } catch (_) {
      return '';
    }
  }
}
```

Note: Add `import '../services/auth_service.dart';` at top.

- [ ] **Step 2: Run analyzer**

```
flutter analyze lib/services/local_service.dart
```
Expected: no issues.

- [ ] **Step 3: Commit**

```
git add lib/services/local_service.dart
git commit -m "feat: add LocalService wrapping drift DB for offline reads/writes"
```

---

## Task 4: SyncService

**Files:**
- Create: `lib/services/sync_service.dart`
- Create: `lib/widgets/conflict_dialog.dart`

- [ ] **Step 1: Create ConflictDialog**

`lib/widgets/conflict_dialog.dart`:
```dart
import 'package:flutter/material.dart';
import '../app_colors.dart';

enum ConflictChoice { keepLocal, keepServer }

class ConflictDialog extends StatelessWidget {
  final String entityTitle;
  final String localSummary;
  final String serverSummary;

  const ConflictDialog({
    super.key,
    required this.entityTitle,
    required this.localSummary,
    required this.serverSummary,
  });

  static Future<ConflictChoice?> show(
    BuildContext context, {
    required String entityTitle,
    required String localSummary,
    required String serverSummary,
  }) {
    return showDialog<ConflictChoice>(
      context: context,
      builder: (_) => ConflictDialog(
        entityTitle: entityTitle,
        localSummary: localSummary,
        serverSummary: serverSummary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Konflikt: $entityTitle',
          style: const TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lokale Version:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(localSummary, style: const TextStyle(color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          const Text('Server-Version:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(serverSummary, style: const TextStyle(color: AppColors.textPrimary)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ConflictChoice.keepServer),
          child: const Text('Server behalten', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ConflictChoice.keepLocal),
          child: const Text('Meine Version', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Create SyncService**

`lib/services/sync_service.dart`:
```dart
import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../models/calendar_event.dart';
import '../models/todo.dart';
import '../widgets/conflict_dialog.dart';
import 'local_service.dart';
import 'supabase_service.dart';

class SyncService {
  static StreamSubscription<List<ConnectivityResult>>? _sub;
  static bool _syncing = false;
  // Navigator key needed to show dialog without BuildContext
  static GlobalKey<NavigatorState>? navigatorKey;

  static void init(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) sync();
    });
  }

  static void dispose() {
    _sub?.cancel();
  }

  static Future<void> sync() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final queue = await LocalService.getPendingQueue();
      for (final entry in queue) {
        await _processEntry(entry);
        await LocalService.removeFromQueue(entry.id);
      }
    } finally {
      _syncing = false;
    }
  }

  static Future<void> _processEntry(dynamic entry) async {
    final table = entry.tableName as String;
    final op = entry.operation as String;
    final payload = jsonDecode(entry.payload as String) as Map<String, dynamic>;

    if (op == 'delete') {
      if (table == 'calendar_events') {
        await SupabaseService.deleteEvent(entry.entityId as String);
      } else {
        await SupabaseService.deleteTodo(entry.entityId as String);
      }
      return;
    }

    // upsert — check for conflict
    if (table == 'calendar_events') {
      final serverRow = await SupabaseService.getEventById(entry.entityId as String);
      if (serverRow != null) {
        final local = CalendarEvent.fromJson(payload);
        final localMs = local.startTime.millisecondsSinceEpoch;
        final serverMs = serverRow.startTime.millisecondsSinceEpoch;
        if (serverMs > localMs) {
          final choice = await _askConflict(local.title, local.toString(), serverRow.toString());
          if (choice == ConflictChoice.keepServer) return; // discard local
        }
      }
      final event = CalendarEvent.fromJson(payload);
      await SupabaseService.saveEvent(event);
    } else {
      final serverRow = await SupabaseService.getTodoById(entry.entityId as String);
      if (serverRow != null) {
        final local = Todo.fromJson(payload);
        final localMs = local.createdAt.millisecondsSinceEpoch;
        final serverMs = serverRow.createdAt.millisecondsSinceEpoch;
        if (serverMs > localMs) {
          final choice = await _askConflict(local.title, local.title, serverRow.title);
          if (choice == ConflictChoice.keepServer) return;
        }
      }
      final todo = Todo.fromJson(payload);
      await SupabaseService.saveTodo(todo);
    }
  }

  static Future<ConflictChoice?> _askConflict(
      String title, String local, String server) async {
    final ctx = navigatorKey?.currentContext;
    if (ctx == null) return ConflictChoice.keepLocal;
    return ConflictDialog.show(ctx,
        entityTitle: title, localSummary: local, serverSummary: server);
  }
}
```

Note: `SupabaseService` needs two new methods: `getEventById(String id)` and `getTodoById(String id)` — simple single-row fetches.

- [ ] **Step 3: Add getEventById / getTodoById to SupabaseService**

In `lib/services/supabase_service.dart`:
```dart
static Future<CalendarEvent?> getEventById(String id) async {
  final rows = await _db.from('calendar_events').select().eq('id', id).eq('user_id', _uid).limit(1);
  if ((rows as List).isEmpty) return null;
  return CalendarEvent.fromJson(rows.first['data'] as Map<String, dynamic>);
}

static Future<Todo?> getTodoById(String id) async {
  final rows = await _db.from('todos').select().eq('id', id).eq('user_id', _uid).limit(1);
  if ((rows as List).isEmpty) return null;
  return Todo.fromJson(rows.first['data'] as Map<String, dynamic>);
}
```

- [ ] **Step 4: Run analyzer**

```
flutter analyze lib/services/sync_service.dart lib/widgets/conflict_dialog.dart lib/services/supabase_service.dart
```
Expected: no issues.

- [ ] **Step 5: Commit**

```
git add lib/services/sync_service.dart lib/widgets/conflict_dialog.dart lib/services/supabase_service.dart
git commit -m "feat: add SyncService, ConflictDialog, and getById methods"
```

---

## Task 5: Wire up in main.dart + seed on first launch

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add GlobalKey and init sequence**

```dart
final _navigatorKey = GlobalKey<NavigatorState>();
```

In `main()`:
```dart
final db = AppDatabase();
LocalService.init(db);
SyncService.init(_navigatorKey);
```

Pass `navigatorKey: _navigatorKey` to `MaterialApp`.

- [ ] **Step 1b: Add getAllEvents() and getAllTodos() to SupabaseService**

In `lib/services/supabase_service.dart`:
```dart
static Future<List<CalendarEvent>> getAllEvents() async {
  final rows = await _db.from('calendar_events').select().eq('user_id', _uid);
  return (rows as List)
      .map((r) => CalendarEvent.fromJson(r['data'] as Map<String, dynamic>))
      .toList();
}

static Future<List<Todo>> getAllTodos() async {
  final rows = await _db.from('todos').select().eq('user_id', _uid);
  return (rows as List)
      .map((r) => Todo.fromJson(r['data'] as Map<String, dynamic>))
      .toList();
}
```

- [ ] **Step 2: Seed local DB on first launch**

On first launch (check a SharedPreferences flag `local_seeded`):
```dart
final prefs = await SharedPreferences.getInstance();
if (prefs.getBool('local_seeded') != true) {
  // fetch all from Supabase and seed local
  final events = await SupabaseService.getAllEvents();
  final todos = await SupabaseService.getAllTodos();
  await LocalService.seedEvents(events);
  await LocalService.seedTodos(todos);
  await prefs.setBool('local_seeded', true);
}
```

Add `getAllEvents()` and `getAllTodos()` to `SupabaseService` (full-table fetch for current user).

- [ ] **Step 3: Replace SupabaseService calls with LocalService in screens**

In `week_screen.dart`, `todo_list_screen.dart`:
- `SupabaseService.eventsForWeek(...)` → `LocalService.eventsForWeek(...)`
- `SupabaseService.todosForWeek(...)` → `LocalService.todosForWeek(...)`
- `SupabaseService.unscheduledTodos()` → `LocalService.unscheduledTodos()`
- `SupabaseService.saveEvent(...)` → `LocalService.saveEvent(...)`
- `SupabaseService.saveTodo(...)` → `LocalService.saveTodo(...)`
- `SupabaseService.deleteEvent(...)` → `LocalService.deleteEvent(...)`
- `SupabaseService.deleteTodo(...)` → `LocalService.deleteTodo(...)`

- [ ] **Step 4: Run analyzer**

```
flutter analyze lib/
```
Expected: no issues.

- [ ] **Step 5: Commit**

```
git add lib/main.dart lib/week/week_screen.dart lib/todos/todo_list_screen.dart
git commit -m "feat: wire LocalService into screens, seed on first launch"
```
