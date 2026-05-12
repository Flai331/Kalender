import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/calendar_event.dart';
import '../models/todo.dart';
import '../models/week_note.dart';
import '../models/series_reminder.dart';
import '../models/yearly_checklist.dart';
import 'auth_service.dart';

class SupabaseService {
  static final _db = Supabase.instance.client;

  static String get _uid => AuthService.userId ?? '';

  // ── CalendarEvents ─────────────────────────────────────────────────────────

  static Stream<List<CalendarEvent>> eventsForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return _db
        .from('calendar_events')
        .stream(primaryKey: ['id'])
        .eq('user_id', _uid)
        .map((rows) => rows
            .map((r) => CalendarEvent.fromJson(r['data'] as Map<String, dynamic>))
            .where((e) =>
                !e.startTime.isBefore(weekStart) && e.startTime.isBefore(weekEnd))
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime)));
  }

  static Future<void> saveEvent(CalendarEvent event) async {
    await _db.from('calendar_events').upsert({
      'id': event.id,
      'user_id': _uid,
      'data': event.toJson(),
    });
  }

  static Future<void> deleteEvent(String id) async {
    await _db.from('calendar_events').delete().eq('id', id).eq('user_id', _uid);
  }

  static Future<List<CalendarEvent>> getEventsForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _db
        .from('calendar_events')
        .select()
        .eq('user_id', _uid);
    return (rows as List)
        .map((r) => CalendarEvent.fromJson(r['data'] as Map<String, dynamic>))
        .where((e) => !e.startTime.isBefore(start) && e.startTime.isBefore(end))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // ── Todos ──────────────────────────────────────────────────────────────────

  static Stream<List<Todo>> unscheduledTodos() {
    return _db
        .from('todos')
        .stream(primaryKey: ['id'])
        .eq('user_id', _uid)
        .map((rows) => rows
            .map((r) => Todo.fromJson(r['data'] as Map<String, dynamic>))
            .where((t) => t.scheduledDate == null && !t.isCompleted)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
  }

  static Stream<List<Todo>> todosForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return _db
        .from('todos')
        .stream(primaryKey: ['id'])
        .eq('user_id', _uid)
        .map((rows) => rows
            .map((r) => Todo.fromJson(r['data'] as Map<String, dynamic>))
            .where((t) =>
                t.scheduledDate != null &&
                !t.scheduledDate!.isBefore(weekStart) &&
                t.scheduledDate!.isBefore(weekEnd))
            .toList());
  }

  static Future<void> saveTodo(Todo todo) async {
    await _db.from('todos').upsert({
      'id': todo.id,
      'user_id': _uid,
      'data': todo.toJson(),
    });
  }

  static Future<void> deleteTodo(String id) async {
    await _db.from('todos').delete().eq('id', id).eq('user_id', _uid);
  }

  static Future<List<Todo>> getTodosForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _db.from('todos').select().eq('user_id', _uid);
    return (rows as List)
        .map((r) => Todo.fromJson(r['data'] as Map<String, dynamic>))
        .where((t) =>
            t.scheduledDate != null &&
            !t.scheduledDate!.isBefore(start) &&
            t.scheduledDate!.isBefore(end))
        .toList();
  }

  static Future<Todo?> getTodoById(String id) async {
    final rows = await _db
        .from('todos')
        .select()
        .eq('id', id)
        .eq('user_id', _uid)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return Todo.fromJson(rows.first['data'] as Map<String, dynamic>);
  }

  static Future<CalendarEvent?> getEventById(String id) async {
    final rows = await _db
        .from('calendar_events')
        .select()
        .eq('id', id)
        .eq('user_id', _uid)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return CalendarEvent.fromJson(rows.first['data'] as Map<String, dynamic>);
  }

  // ── WeekNotes ──────────────────────────────────────────────────────────────

  static Future<WeekNote> getWeekNote(String weekKey) async {
    final rows = await _db
        .from('week_notes')
        .select()
        .eq('user_id', _uid)
        .eq('week_key', weekKey)
        .limit(1);
    if ((rows as List).isNotEmpty) {
      return WeekNote.fromJson(rows.first['data'] as Map<String, dynamic>);
    }
    return WeekNote(weekKey: weekKey);
  }

  static Future<void> saveWeekNote(WeekNote note) async {
    await _db.from('week_notes').upsert({
      'week_key': note.weekKey,
      'user_id': _uid,
      'data': note.toJson(),
    });
  }

  // ── SeriesReminders ────────────────────────────────────────────────────────

  static Stream<List<SeriesReminder>> remindersStream() {
    return _db
        .from('series_reminders')
        .stream(primaryKey: ['id'])
        .eq('user_id', _uid)
        .map((rows) => rows
            .map((r) => SeriesReminder.fromJson(r['data'] as Map<String, dynamic>))
            .toList());
  }

  static Future<List<SeriesReminder>> getReminders() async {
    final rows = await _db
        .from('series_reminders')
        .select()
        .eq('user_id', _uid);
    return (rows as List)
        .map((r) => SeriesReminder.fromJson(r['data'] as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveReminder(SeriesReminder reminder) async {
    await _db.from('series_reminders').upsert({
      'id': reminder.id,
      'user_id': _uid,
      'data': reminder.toJson(),
    });
  }

  static Future<void> deleteReminder(String id) async {
    await _db.from('series_reminders').delete().eq('id', id).eq('user_id', _uid);
  }

  // ── YearlyChecklists ───────────────────────────────────────────────────────

  static Stream<List<YearlyChecklist>> yearlyChecklistsStream() {
    return _db
        .from('yearly_checklists')
        .stream(primaryKey: ['id'])
        .eq('user_id', _uid)
        .map((rows) => rows
            .map((r) =>
                YearlyChecklist.fromJson(r['data'] as Map<String, dynamic>))
            .toList());
  }

  static Future<List<YearlyChecklist>> getYearlyChecklists() async {
    final rows = await _db
        .from('yearly_checklists')
        .select()
        .eq('user_id', _uid);
    return (rows as List)
        .map((r) =>
            YearlyChecklist.fromJson(r['data'] as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveYearlyChecklist(YearlyChecklist checklist) async {
    await _db.from('yearly_checklists').upsert({
      'id': checklist.id,
      'user_id': _uid,
      'data': checklist.toJson(),
    });
  }

  static Future<void> deleteYearlyChecklist(String id) async {
    await _db
        .from('yearly_checklists')
        .delete()
        .eq('id', id)
        .eq('user_id', _uid);
  }

  // ── Batch: Todos nach einem Zeitpunkt verschieben ──────────────────────────

  static Future<void> shiftTodosAfter({
    required DateTime day,
    required int afterHour,
    required int afterMinute,
    required int shiftMinutes,
    required bool onlyFlexible,
  }) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final rows = await _db.from('todos').select().eq('user_id', _uid);
    final todos = (rows as List)
        .map((r) => Todo.fromJson(r['data'] as Map<String, dynamic>))
        .where((t) =>
            t.scheduledDate != null &&
            !t.scheduledDate!.isBefore(start) &&
            t.scheduledDate!.isBefore(end))
        .toList();

    for (final todo in todos) {
      if (onlyFlexible && todo.isFixed) continue;
      if (todo.scheduledStartHour == null) continue;

      final todoMinutes =
          todo.scheduledStartHour! * 60 + (todo.scheduledStartMinute ?? 0);
      final afterMinutes = afterHour * 60 + afterMinute;
      if (todoMinutes <= afterMinutes) continue;

      final totalMinutes = todoMinutes + shiftMinutes;
      final newHour = (totalMinutes ~/ 60).clamp(0, 23);
      final newMinute = (totalMinutes % 60).clamp(0, 59);

      final updated = todo.copyWith(
        scheduledStartHour: newHour,
        scheduledStartMinute: newMinute,
      );
      await saveTodo(updated);
    }
  }
}
