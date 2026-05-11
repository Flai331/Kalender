import '../models/todo.dart';
import 'supabase_service.dart';

class ShiftService {
  /// Verschiebt alle flexiblen Todos nach dem abgeschlossenen Todo
  /// um [deltaMinutes] Minuten (negativ = früher, positiv = später).
  static Future<void> shiftAfterTodo({
    required Todo completedTodo,
    required int deltaMinutes, // negativ = früher fertig, positiv = zu spät
  }) async {
    if (completedTodo.scheduledDate == null ||
        completedTodo.scheduledStartHour == null ||
        deltaMinutes == 0) {
      return;
    }

    final startMinutes = completedTodo.scheduledStartHour! * 60 +
        (completedTodo.scheduledStartMinute ?? 0);
    final scheduledEndMinutes = startMinutes + completedTodo.estimatedMinutes;
    final afterHour = scheduledEndMinutes ~/ 60;
    final afterMinute = scheduledEndMinutes % 60;

    await SupabaseService.shiftTodosAfter(
      day: completedTodo.scheduledDate!,
      afterHour: afterHour,
      afterMinute: afterMinute,
      shiftMinutes: deltaMinutes, // positiv = todos nach hinten, negativ = nach vorne
      onlyFlexible: true,
    );
  }

  /// Berechnet den Zeitdelta: positiv = zu spät, negativ = früher fertig
  static int computeDelta({required Todo todo, required DateTime actualEnd}) {
    if (todo.scheduledDate == null || todo.scheduledStartHour == null) return 0;
    final scheduledEnd = DateTime(
      todo.scheduledDate!.year,
      todo.scheduledDate!.month,
      todo.scheduledDate!.day,
      todo.scheduledStartHour!,
      todo.scheduledStartMinute ?? 0,
    ).add(Duration(minutes: todo.estimatedMinutes));
    return actualEnd.difference(scheduledEnd).inMinutes;
  }

  /// Gibt eine Preview-Liste zurück, wie sich Todos nach dem Shift verhalten würden
  static List<Todo> previewShift({
    required List<Todo> todos,
    required Todo completedTodo,
    required int savedMinutes,
  }) {
    if (completedTodo.scheduledStartHour == null) return todos;

    final afterMinutes = completedTodo.scheduledStartHour! * 60 +
        (completedTodo.scheduledStartMinute ?? 0) +
        completedTodo.estimatedMinutes;

    return todos.map((todo) {
      if (todo.isFixed) return todo;
      if (todo.scheduledStartHour == null) return todo;
      if (todo.id == completedTodo.id) return todo;

      final todoMinutes =
          todo.scheduledStartHour! * 60 + (todo.scheduledStartMinute ?? 0);
      if (todoMinutes <= afterMinutes) return todo;

      final newTotalMinutes = todoMinutes - savedMinutes;
      final newHour = (newTotalMinutes ~/ 60).clamp(0, 23);
      final newMinute = (newTotalMinutes % 60).clamp(0, 59);

      return todo.copyWith(
        scheduledStartHour: newHour,
        scheduledStartMinute: newMinute,
      );
    }).toList();
  }
}
