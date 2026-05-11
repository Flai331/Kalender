import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/todo.dart';

/// Aktualisiert das Android-Homescreen-Widget mit heutigen Todos
class WidgetService {
  static const _channel = MethodChannel('com.example.kalender/widget');

  static Future<void> update({
    required List<Todo> todayTodos,
    Todo? activeTask,
    Duration? activeTimer,
  }) async {
    if (kIsWeb) return;

    try {
      final todosJson = jsonEncode(todayTodos
          .map((t) => {
                'title': t.title,
                'done': t.status == TodoStatus.done,
                'estimatedMinutes': t.estimatedMinutes,
              })
          .toList());

      final timerLabel = activeTimer != null
          ? _formatDuration(activeTimer)
          : '';

      await _channel.invokeMethod('updateWidgetData', {
        'today_todos': todosJson,
        'active_task': activeTask?.title ?? '',
        'active_timer': timerLabel,
      });
    } catch (e) {
      debugPrint('WidgetService: $e');
    }
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
