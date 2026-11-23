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
import '../models/place.dart';
import '../models/vorlage.dart';
import '../models/week_note.dart';
import '../models/app_category.dart';

class LocalService {
  static late AppDatabase _db;

  /// Kennung, unter der gespeichert wird. Einmalig je Installation; ohne sie
  /// landete alles unter '' .
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

  // ── CalendarEvents ────────────────────────────────────────────────────────

  /// Alle Termine eines Zeitraums: `start` gehoert dazu, `end` nicht mehr.
  /// Wochen- und Monatsansicht lesen beide hierueber, nur mit anderer Spanne.
  ///
  /// Mitgenommen wird jeder Termin, der in den Zeitraum hineinreicht — nicht
  /// nur die, die darin anfangen. Sonst fehlt eine Reise, die am Monatsende
  /// beginnt, im Folgemonat.
  static Stream<List<CalendarEvent>> eventsForRange(
      DateTime start, DateTime end) {
    return (_db.select(_db.eventsCache)
          ..where((e) => e.userId.equals(_uid)))
        .watch()
        .map((rows) => rows
            .map((r) => CalendarEvent.fromJson(
                jsonDecode(r.data) as Map<String, dynamic>))
            .where((e) =>
                e.startTime.isBefore(end) && !e.endTime.isBefore(start))
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
  }

  static Future<void> deleteEvent(String id) async {
    await (_db.delete(_db.eventsCache)
          ..where((e) => e.id.equals(id)))
        .go();
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

  /// Alle eingeplanten Todos eines Zeitraums, `end` nicht mehr enthalten.
  static Stream<List<Todo>> todosForRange(DateTime start, DateTime end) {
    return (_db.select(_db.todosCache)
          ..where((t) => t.userId.equals(_uid)))
        .watch()
        .map((rows) => rows
            .map((r) =>
                Todo.fromJson(jsonDecode(r.data) as Map<String, dynamic>))
            .where((t) =>
                t.scheduledDate != null &&
                !t.scheduledDate!.isBefore(start) &&
                t.scheduledDate!.isBefore(end))
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
  }

  static Future<void> deleteTodo(String id) async {
    await (_db.delete(_db.todosCache)..where((t) => t.id.equals(id))).go();
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
  }

  static Future<void> deleteAnnualEvent(String id) async {
    await (_db.delete(_db.annualEventsCache)..where((e) => e.id.equals(id)))
        .go();
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
  }

  static Future<void> deleteReminder(String id) async {
    await (_db.delete(_db.seriesRemindersCache)..where((r) => r.id.equals(id)))
        .go();
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
  }

  static Future<void> deleteYearlyChecklist(String id) async {
    await (_db.delete(_db.yearlyChecklistsCache)..where((c) => c.id.equals(id)))
        .go();
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

  /// Offene To-dos **ohne jede Zeitangabe** — die aus der Leiste unten.
  ///
  /// Dieselbe Auswahl wie [unscheduledTodos], nur als einmalige Abfrage und
  /// ohne die, die ohnehin niemand verschieben darf.
  static Future<List<Todo>> getOpenTodosOhneZeit() async {
    final todos = await getAllTodos();
    return todos
        .where((t) =>
            t.scheduledDate == null &&
            !t.isCompleted &&
            t.status != TodoStatus.done &&
            !t.isFixed)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Offene To-dos **mit** Uhrzeit, ab [day] aufwaerts.
  ///
  /// Der Auto-Shift sieht nur den heutigen Tag an. Ein To-do, das im Dienst
  /// naechsten Mittwoch steht, muss aber mitkommen, wenn der Dienst sich
  /// verschiebt — dafuer braucht es auch die kuenftigen Tage.
  ///
  /// Feste To-dos sind ausgenommen: "fest" heisst, dass die App sie nicht
  /// verschiebt.
  static Future<List<Todo>> getOpenTodosMitZeitAb(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final todos = await _allTodos();
    return todos
        .where((t) =>
            t.scheduledDate != null &&
            !t.scheduledDate!.isBefore(start) &&
            t.scheduledStartHour != null &&
            !t.isCompleted &&
            t.status != TodoStatus.done &&
            !t.isFixed)
        .toList()
      ..sort((a, b) {
        final byDay = a.scheduledDate!.compareTo(b.scheduledDate!);
        if (byDay != 0) return byDay;
        final am =
            a.scheduledStartHour! * 60 + (a.scheduledStartMinute ?? 0);
        final bm =
            b.scheduledStartHour! * 60 + (b.scheduledStartMinute ?? 0);
        return am.compareTo(bm);
      });
  }

  /// Loest die Bindung an einen Kalender und gibt die Zahl der geaenderten
  /// To-dos zurueck. Gedacht fuer das Entfernen eines Abonnements: ohne das
  /// haengt ein To-do an einem Kalender, den es nicht mehr gibt, und findet
  /// nie wieder einen Platz.
  static Future<int> loeseKalenderBindung(String kalenderId) async {
    var changed = 0;
    for (final todo in await getAllTodos()) {
      if (todo.requiredCalendarId != kalenderId) continue;
      await saveTodo(todo.copyWith(requiredCalendarId: null));
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
  /// beginnen, um [shiftMinutes].
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

  /// Gibt eine leere Notiz zurueck, wenn fuer die Woche nichts gespeichert ist.
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

  /// Schreibt die Liste. Eine Zeile je Benutzer, die ganze Liste in einem
  /// Rutsch — die Reihenfolge gehoert zur Liste, nicht zum einzelnen Eintrag.
  static Future<void> saveCategories(List<AppCategory> items) async {
    await _writeCategories(items);
  }

  /// Wie [saveCategories]; eigener Name fuer das Einspielen einer Sicherung,
  /// passend zu [seedEvents] und den uebrigen seed-Methoden.
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

  // ── Orte ─────────────────────────────────────────────────────────────────

  /// Die gespeicherten Orte, oder eine leere Liste.
  static Future<List<Place>> getPlaces() async {
    final rows = await (_db.select(_db.placesCache)
          ..where((c) => c.userId.equals(_uid)))
        .get();
    if (rows.isEmpty) return [];
    try {
      return Place.listFromJson(rows.first.data);
    } catch (_) {
      // Lieber keine Orte als ein Absturz beim Start.
      return [];
    }
  }

  /// Schreibt die ganze Liste. Die Rangliste gehoert zur Liste, nicht zum
  /// einzelnen Ort — darum eine Zeile je Benutzer, wie bei den Kategorien.
  static Future<void> savePlaces(List<Place> items) => _writePlaces(items);

  /// Wie [savePlaces]; eigener Name fuer das Einspielen einer Sicherung.
  static Future<void> seedPlaces(List<Place> items) => _writePlaces(items);

  static Future<void> _writePlaces(List<Place> items) async {
    await _db.into(_db.placesCache).insertOnConflictUpdate(
          PlacesCacheCompanion(
            userId: Value(_uid),
            data: Value(Place.listToJson(items)),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  // ── Vorlagen ──────────────────────────────────────────────────────────────

  static Future<List<Vorlage>> getVorlagen() async {
    final rows = await (_db.select(_db.vorlagenCache)
          ..where((c) => c.userId.equals(_uid)))
        .get();
    if (rows.isEmpty) return [];
    try {
      return (jsonDecode(rows.first.data) as List)
          .map((e) => Vorlage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Lieber keine Vorlagen als ein Absturz beim Oeffnen.
      return [];
    }
  }

  static Future<void> saveVorlagen(List<Vorlage> items) =>
      _writeVorlagen(items);

  /// Wie [saveVorlagen]; eigener Name fuer das Einspielen einer Sicherung.
  static Future<void> seedVorlagen(List<Vorlage> items) =>
      _writeVorlagen(items);

  static Future<void> _writeVorlagen(List<Vorlage> items) async {
    await _db.into(_db.vorlagenCache).insertOnConflictUpdate(
          VorlagenCacheCompanion(
            userId: Value(_uid),
            data: Value(jsonEncode(items.map((v) => v.toJson()).toList())),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  // ── Alles loeschen ────────────────────────────────────────────────────────

  /// Raeumt alle Daten dieses Benutzers weg.
  ///
  /// Fuer das Einspielen einer Sicherung: danach steht genau das da, was in
  /// der Datei stand, und nicht eine Mischung aus beidem.
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
      await (_db.delete(_db.placesCache)..where((t) => t.userId.equals(_uid)))
          .go();
      await (_db.delete(_db.vorlagenCache)..where((t) => t.userId.equals(_uid)))
          .go();
    });
  }

  /// Fuellt den Zwischenspeicher aus einer Sicherung.
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

  /// Unter dieser Kennung wird gespeichert und gelesen.
  static String get _uid => _deviceUid ?? '';

  /// Die Kennung, unter der gerade gespeichert wird. Fuer Tests und Diagnose.
  static String get currentUid => _uid;
}
