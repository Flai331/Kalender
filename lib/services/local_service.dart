import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';
import '../models/calendar_event.dart';
import '../models/todo.dart';
import '../models/annual_event.dart';
import '../models/series_reminder.dart';
import '../models/yearly_checklist.dart';
import '../models/week_note.dart';
import '../models/app_category.dart';
import 'auth_service.dart';

class LocalService {
  static late AppDatabase _db;

  /// Kennung, unter der gespeichert wird, solange keine Supabase-Sitzung
  /// besteht. Ohne sie landete alles unter '' und war nach einer spaeteren
  /// Anmeldung unerreichbar.
  static String? _deviceUid;

  static const String _deviceUidKey = 'local_device_user_id';

  /// Muss vor dem ersten Zugriff abgewartet werden: legt die Geraete-Kennung
  /// an oder liest sie aus den Einstellungen.
  static Future<void> init(AppDatabase db) async {
    _db = db;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceUidKey);
    if (id == null) {
      id = 'local-${const Uuid().v4()}';
      await prefs.setString(_deviceUidKey, id);
    }
    _deviceUid = id;
  }

  /// Die Kennung der aktuellen Sitzung, oder null.
  ///
  /// Gekapselt, weil `AuthService.userId` auf `Supabase.instance` zugreift und
  /// das wirft, wenn Supabase nie initialisiert wurde (nicht konfiguriert oder
  /// initialize ist gescheitert). Die lokale Schicht muss das ueberleben.
  static String? get sessionUid {
    try {
      return AuthService.userId;
    } catch (_) {
      return null;
    }
  }

  /// Schreibt alle unter der Geraete-Kennung gespeicherten Zeilen auf
  /// [realUid] um. Aufzurufen, sobald eine Sitzung zustande kommt — sonst
  /// bleiben offline angelegte Daten unsichtbar.
  ///
  /// Gibt die Anzahl der umgeschriebenen Zeilen zurueck.
  static Future<int> adoptLocalRows(String realUid) async {
    final from = _deviceUid;
    if (from == null || from == realUid || realUid.isEmpty) return 0;

    var count = 0;
    Future<void> move(String table) async {
      count += await _db.customUpdate(
        'UPDATE $table SET user_id = ? WHERE user_id = ?',
        variables: [Variable<String>(realUid), Variable<String>(from)],
        updates: const {},
      );
    }

    await move('events_cache');
    await move('todos_cache');
    await move('annual_events_cache');
    await move('series_reminders_cache');
    await move('yearly_checklists_cache');
    await move('week_notes_cache');

    // Kategorien: user_id ist hier der Primaerschluessel. Liegt schon eine
    // Zeile der echten Sitzung vor, wuerde ein Verschieben sie verletzen —
    // dann gilt die der Sitzung, und die Geraete-Zeile fliegt weg.
    final ownRow = await (_db.select(_db.categoriesCache)
          ..where((c) => c.userId.equals(realUid)))
        .get();
    if (ownRow.isEmpty) {
      await move('categories_cache');
    } else {
      await (_db.delete(_db.categoriesCache)
            ..where((c) => c.userId.equals(from)))
          .go();
    }
    return count;
  }

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

  // ── AnnualEvents ─────────────────────────────────────────────────────────

  static Stream<List<AnnualEvent>> annualEvents() {
    return (_db.select(_db.annualEventsCache)
          ..where((e) => e.userId.equals(_uid)))
        .watch()
        .map((rows) => rows
            .map((r) => AnnualEvent.fromJson(
                jsonDecode(r.data) as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)));
  }

  static Future<void> saveAnnualEvent(AnnualEvent event) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.annualEventsCache).insertOnConflictUpdate(
          AnnualEventsCacheCompanion(
            id: Value(event.id),
            userId: Value(_uid),
            data: Value(jsonEncode(event.toJson())),
            updatedAt: Value(now),
          ),
        );
    await _enqueue('annual_events', 'upsert', event.id, event.toJson());
  }

  static Future<void> deleteAnnualEvent(String id) async {
    await (_db.delete(_db.annualEventsCache)..where((e) => e.id.equals(id)))
        .go();
    await _enqueue('annual_events', 'delete', id, {'id': id});
  }

  // ── SeriesReminders ──────────────────────────────────────────────────────

  static Stream<List<SeriesReminder>> remindersStream() {
    return (_db.select(_db.seriesRemindersCache)
          ..where((r) => r.userId.equals(_uid)))
        .watch()
        .map((rows) => rows
            .map((r) => SeriesReminder.fromJson(
                jsonDecode(r.data) as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title)));
  }

  /// Einmaliger Abruf — u.a. für die Notification-Planung beim App-Start,
  /// die auch ohne Netz funktionieren muss.
  static Future<List<SeriesReminder>> getReminders() async {
    final rows = await (_db.select(_db.seriesRemindersCache)
          ..where((r) => r.userId.equals(_uid)))
        .get();
    return rows
        .map((r) =>
            SeriesReminder.fromJson(jsonDecode(r.data) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveReminder(SeriesReminder reminder) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.seriesRemindersCache).insertOnConflictUpdate(
          SeriesRemindersCacheCompanion(
            id: Value(reminder.id),
            userId: Value(_uid),
            data: Value(jsonEncode(reminder.toJson())),
            updatedAt: Value(now),
          ),
        );
    await _enqueue('series_reminders', 'upsert', reminder.id, reminder.toJson());
  }

  static Future<void> deleteReminder(String id) async {
    await (_db.delete(_db.seriesRemindersCache)..where((r) => r.id.equals(id)))
        .go();
    await _enqueue('series_reminders', 'delete', id, {'id': id});
  }

  // ── YearlyChecklists ─────────────────────────────────────────────────────

  static Stream<List<YearlyChecklist>> yearlyChecklistsStream() {
    return (_db.select(_db.yearlyChecklistsCache)
          ..where((c) => c.userId.equals(_uid)))
        .watch()
        .map((rows) => rows
            .map((r) => YearlyChecklist.fromJson(
                jsonDecode(r.data) as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title)));
  }

  static Future<List<YearlyChecklist>> getYearlyChecklists() async {
    final rows = await (_db.select(_db.yearlyChecklistsCache)
          ..where((c) => c.userId.equals(_uid)))
        .get();
    return rows
        .map((r) => YearlyChecklist.fromJson(
            jsonDecode(r.data) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveYearlyChecklist(YearlyChecklist checklist) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.yearlyChecklistsCache).insertOnConflictUpdate(
          YearlyChecklistsCacheCompanion(
            id: Value(checklist.id),
            userId: Value(_uid),
            data: Value(jsonEncode(checklist.toJson())),
            updatedAt: Value(now),
          ),
        );
    await _enqueue(
        'yearly_checklists', 'upsert', checklist.id, checklist.toJson());
  }

  static Future<void> deleteYearlyChecklist(String id) async {
    await (_db.delete(_db.yearlyChecklistsCache)..where((c) => c.id.equals(id)))
        .go();
    await _enqueue('yearly_checklists', 'delete', id, {'id': id});
  }

  /// Alle Todos des angemeldeten Benutzers aus dem Cache.
  static Future<List<Todo>> getAllTodos() => _allTodos();

  /// Alle Termine des angemeldeten Benutzers aus dem Cache.
  static Future<List<CalendarEvent>> getAllEvents() async {
    final rows = await (_db.select(_db.eventsCache)
          ..where((e) => e.userId.equals(_uid)))
        .get();
    return rows
        .map((r) =>
            CalendarEvent.fromJson(jsonDecode(r.data) as Map<String, dynamic>))
        .toList();
  }

  /// Alle Jahres-Events des angemeldeten Benutzers aus dem Cache.
  static Future<List<AnnualEvent>> getAllAnnualEvents() async {
    final rows = await (_db.select(_db.annualEventsCache)
          ..where((e) => e.userId.equals(_uid)))
        .get();
    return rows
        .map((r) =>
            AnnualEvent.fromJson(jsonDecode(r.data) as Map<String, dynamic>))
        .toList();
  }

  /// Wie viele Eintraege an einer Kategorie haengen. Gezaehlt wird alles, was
  /// einen Kategorie-Schluessel traegt — auch die Bedingung "nur waehrend
  /// Terminen der Kategorie X" an einem To-do.
  static Future<int> countByCategory(String key) async {
    final todos = await getAllTodos();
    final events = await getAllEvents();
    final annual = await getAllAnnualEvents();
    return todos
            .where((t) => t.category == key || t.requiredCategory == key)
            .length +
        events.where((e) => e.category == key).length +
        annual.where((a) => a.category == key).length;
  }

  /// Haengt alles von [from] auf [to] um und gibt die Zahl der geaenderten
  /// Eintraege zurueck. Gedacht fuer das Loeschen einer Kategorie: ohne das
  /// behielten die Eintraege einen Schluessel, den es nicht mehr gibt.
  static Future<int> reassignCategory(String from, String to) async {
    if (from == to) return 0;
    var changed = 0;

    for (final todo in await getAllTodos()) {
      final hitsCategory = todo.category == from;
      final hitsRequired = todo.requiredCategory == from;
      if (!hitsCategory && !hitsRequired) continue;
      await saveTodo(todo.copyWith(
        category: hitsCategory ? to : null,
        requiredCategory: hitsRequired ? to : todo.requiredCategory,
      ));
      changed++;
    }

    for (final event in await getAllEvents()) {
      if (event.category != from) continue;
      await saveEvent(event.copyWith(category: to));
      changed++;
    }

    for (final annual in await getAllAnnualEvents()) {
      if (annual.category != from) continue;
      await saveAnnualEvent(annual.copyWith(category: to));
      changed++;
    }

    return changed;
  }

  /// Alle Todos des angemeldeten Benutzers aus dem Cache.
  static Future<List<Todo>> _allTodos() async {
    final rows = await (_db.select(_db.todosCache)
          ..where((t) => t.userId.equals(_uid)))
        .get();
    return rows
        .map((r) => Todo.fromJson(jsonDecode(r.data) as Map<String, dynamic>))
        .toList();
  }

  static Future<Todo?> getTodoById(String id) async {
    final rows = await (_db.select(_db.todosCache)
          ..where((t) => t.id.equals(id) & t.userId.equals(_uid)))
        .get();
    if (rows.isEmpty) return null;
    return Todo.fromJson(jsonDecode(rows.first.data) as Map<String, dynamic>);
  }

  /// Offene To-dos, die auf einen Tag VOR [day] eingeplant sind.
  ///
  /// Gedacht fuer das Nachholen: der Auto-Shift sieht nur den heutigen Tag an,
  /// also bleibt alles liegen, was an einem vergangenen Tag offen geblieben
  /// ist. Feste To-dos sind ausgenommen — "fest" heisst, dass die App sie
  /// nicht verschiebt.
  static Future<List<Todo>> getOpenTodosBefore(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final todos = await _allTodos();
    return todos
        .where((t) =>
            t.scheduledDate != null &&
            t.scheduledDate!.isBefore(start) &&
            !t.isCompleted &&
            t.status != TodoStatus.done &&
            !t.isFixed)
        .toList()
      ..sort((a, b) {
        final byDay = a.scheduledDate!.compareTo(b.scheduledDate!);
        if (byDay != 0) return byDay;
        final am =
            (a.scheduledStartHour ?? 0) * 60 + (a.scheduledStartMinute ?? 0);
        final bm =
            (b.scheduledStartHour ?? 0) * 60 + (b.scheduledStartMinute ?? 0);
        return am.compareTo(bm);
      });
  }

  static Future<List<Todo>> getTodosForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final todos = await _allTodos();
    return todos
        .where((t) =>
            t.scheduledDate != null &&
            !t.scheduledDate!.isBefore(start) &&
            t.scheduledDate!.isBefore(end))
        .toList()
      ..sort((a, b) {
        final am = (a.scheduledStartHour ?? 0) * 60 +
            (a.scheduledStartMinute ?? 0);
        final bm = (b.scheduledStartHour ?? 0) * 60 +
            (b.scheduledStartMinute ?? 0);
        return am.compareTo(bm);
      });
  }

  /// Verschiebt die Todos eines Tages, die ab [afterHour]:[afterMinute]
  /// beginnen, um [shiftMinutes]. Gleiche Logik wie vorher in
  /// SupabaseService.shiftTodosAfter, nur gegen den lokalen Cache — damit
  /// Auto-Shift auch ohne Netz greift.
  ///
  /// [skipTodoId] bleibt in jedem Fall liegen — gedacht fuer das gerade
  /// abgeschlossene To-do, das seine eigene Verschiebung ausloest.
  static Future<void> shiftTodosAfter({
    required DateTime day,
    required int afterHour,
    required int afterMinute,
    required int shiftMinutes,
    required bool onlyFlexible,
    String? skipTodoId,
  }) async {
    final todos = await getTodosForDate(day);
    final afterMinutes = afterHour * 60 + afterMinute;

    for (final todo in todos) {
      if (skipTodoId != null && todo.id == skipTodoId) continue;
      if (onlyFlexible && todo.isFixed) continue;
      if (todo.scheduledStartHour == null) continue;

      final todoMinutes =
          todo.scheduledStartHour! * 60 + (todo.scheduledStartMinute ?? 0);
      // Die Grenze gehoert dazu: der Auto-Shift legt Todos lueckenlos
      // hintereinander, das naechste beginnt also genau zur Soll-Endzeit
      // [afterHour]:[afterMinute]. Mit "<=" blieb genau dieses eine stehen,
      // waehrend alle spaeteren wanderten.
      if (todoMinutes < afterMinutes) continue;

      final totalMinutes = todoMinutes + shiftMinutes;
      final newHour = (totalMinutes ~/ 60).clamp(0, 23);
      final newMinute = (totalMinutes % 60).clamp(0, 59);

      await saveTodo(todo.copyWith(
        scheduledStartHour: newHour,
        scheduledStartMinute: newMinute,
      ));
    }
  }

  // ── WeekNotes ────────────────────────────────────────────────────────────

  /// Gibt eine leere Notiz zurueck, wenn fuer die Woche nichts gespeichert ist
  /// — genauso wie die Supabase-Variante vorher.
  static Future<WeekNote> getWeekNote(String weekKey) async {
    final rows = await (_db.select(_db.weekNotesCache)
          ..where((n) => n.weekKey.equals(weekKey) & n.userId.equals(_uid)))
        .get();
    if (rows.isEmpty) return WeekNote(weekKey: weekKey);
    return WeekNote.fromJson(
        jsonDecode(rows.first.data) as Map<String, dynamic>);
  }

  static Future<List<WeekNote>> getAllWeekNotes() async {
    final rows = await (_db.select(_db.weekNotesCache)
          ..where((n) => n.userId.equals(_uid)))
        .get();
    return rows
        .map((r) => WeekNote.fromJson(jsonDecode(r.data) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveWeekNote(WeekNote note) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.weekNotesCache).insertOnConflictUpdate(
          WeekNotesCacheCompanion(
            weekKey: Value(note.weekKey),
            userId: Value(_uid),
            data: Value(jsonEncode(note.toJson())),
            updatedAt: Value(now),
          ),
        );
    // entityId ist hier der Wochenschluessel — er identifiziert die Zeile.
    await _enqueue('week_notes', 'upsert', note.weekKey, note.toJson());
  }

  // ── Kategorien ────────────────────────────────────────────────────────────

  /// Die gespeicherte Liste, oder null, wenn fuer diesen Benutzer noch keine
  /// Zeile existiert.
  static Future<List<AppCategory>?> getCategories() async {
    final rows = await (_db.select(_db.categoriesCache)
          ..where((c) => c.userId.equals(_uid)))
        .get();
    if (rows.isEmpty) return null;
    return AppCategory.listFromJson(jsonDecode(rows.first.data));
  }

  /// Schreibt die Liste und meldet sie zum Hochladen an.
  static Future<void> saveCategories(List<AppCategory> items) async {
    await _writeCategories(items);
    // entityId ist die Benutzerkennung — sie identifiziert die Zeile, denn es
    // gibt genau eine je Benutzer. Dadurch fasst _enqueue mehrere Aenderungen
    // zu einem Auftrag zusammen.
    await _enqueue('categories', 'upsert', _uid, AppCategory.listToJson(items));
  }

  /// Wie [saveCategories], aber ohne Sync-Auftrag — fuer eine Liste, die
  /// gerade vom Server kam, und fuer die mitgelieferten Vorgaben.
  static Future<void> seedCategories(List<AppCategory> items) async {
    await _writeCategories(items);
  }

  static Future<void> _writeCategories(List<AppCategory> items) async {
    await _db.into(_db.categoriesCache).insertOnConflictUpdate(
          CategoriesCacheCompanion(
            userId: Value(_uid),
            data: Value(jsonEncode(AppCategory.listToJson(items))),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  // ── Alles loeschen ────────────────────────────────────────────────────────

  /// Raeumt alle Daten dieses Benutzers weg, samt wartender Sync-Auftraege.
  ///
  /// Fuer das Einspielen einer Sicherung: danach steht genau das da, was in
  /// der Datei stand, und nicht eine Mischung aus beidem. Die Auftraege
  /// muessen mit weg — sie gehoeren zu Zeilen, die es nicht mehr gibt.
  static Future<void> clearAll() async {
    await _db.transaction(() async {
      await (_db.delete(_db.eventsCache)..where((t) => t.userId.equals(_uid)))
          .go();
      await (_db.delete(_db.todosCache)..where((t) => t.userId.equals(_uid)))
          .go();
      await (_db.delete(_db.annualEventsCache)
            ..where((t) => t.userId.equals(_uid)))
          .go();
      await (_db.delete(_db.seriesRemindersCache)
            ..where((t) => t.userId.equals(_uid)))
          .go();
      await (_db.delete(_db.yearlyChecklistsCache)
            ..where((t) => t.userId.equals(_uid)))
          .go();
      await (_db.delete(_db.weekNotesCache)..where((t) => t.userId.equals(_uid)))
          .go();
      await (_db.delete(_db.categoriesCache)..where((t) => t.userId.equals(_uid)))
          .go();
      await _db.delete(_db.syncQueue).go();
    });
  }

  // ── Sync queue ────────────────────────────────────────────────────────────

  static Future<void> _enqueue(
      String table, String operation, String entityId, Map<String, dynamic> payload) async {
    // Offene Auftraege desselben Eintrags zusammenfassen. Ein ueberfaelliges
    // To-do wird jede Minute neu auf "jetzt" geschrieben; ohne das staende
    // eine Stunde spaeter sechzigmal derselbe Datensatz in der Schlange und
    // ginge sechzigmal an Supabase. Jeder upsert traegt den vollstaendigen
    // Datensatz, der aelteste ist also nichts wert.
    //
    // Geloescht und neu eingestellt, nicht ueberschrieben: der SyncService
    // kann gerade dabei sein, genau diese Zeile zu verschicken, und raeumt sie
    // danach anhand ihrer id weg. Eine ueberschriebene Zeile waere damit samt
    // der neuen Aenderung verschwunden — eine neue Zeile bleibt stehen und
    // geht beim naechsten Durchgang raus.
    await (_db.delete(_db.syncQueue)
          ..where((q) {
            final sameEntity =
                q.targetTable.equals(table) & q.entityId.equals(entityId);
            // Vor einem delete faellt alles Offene weg. Ein upsert raeumt nur
            // andere upserts ab und laesst ein wartendes delete stehen, sonst
            // kippte die Reihenfolge der beiden und der Eintrag verschwaende
            // auf dem Server.
            return operation == 'delete'
                ? sameEntity
                : sameEntity & q.operation.equals('upsert');
          }))
        .go();

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

  static Future<void> seedAnnualEvents(List<AnnualEvent> events) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final e in events) {
        batch.insert(
          _db.annualEventsCache,
          AnnualEventsCacheCompanion(
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

  static Future<void> seedReminders(List<SeriesReminder> reminders) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final r in reminders) {
        batch.insert(
          _db.seriesRemindersCache,
          SeriesRemindersCacheCompanion(
            id: Value(r.id),
            userId: Value(_uid),
            data: Value(jsonEncode(r.toJson())),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  static Future<void> seedYearlyChecklists(
      List<YearlyChecklist> checklists) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final c in checklists) {
        batch.insert(
          _db.yearlyChecklistsCache,
          YearlyChecklistsCacheCompanion(
            id: Value(c.id),
            userId: Value(_uid),
            data: Value(jsonEncode(c.toJson())),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  static Future<void> seedWeekNotes(List<WeekNote> notes) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final n in notes) {
        batch.insert(
          _db.weekNotesCache,
          WeekNotesCacheCompanion(
            weekKey: Value(n.weekKey),
            userId: Value(_uid),
            data: Value(jsonEncode(n.toJson())),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Unter dieser Kennung wird gespeichert und gelesen: die Sitzung, wenn es
  /// eine gibt, sonst die Geraete-Kennung.
  static String get _uid => sessionUid ?? _deviceUid ?? '';

  /// Die Kennung, unter der gerade gespeichert wird. Fuer Tests und Diagnose.
  static String get currentUid => _uid;
}
