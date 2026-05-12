import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/todo.dart';

class WidgetService {
  static const _appGroupId = 'group.com.example.kalender';
  static const _androidWidgetName = 'TodoWidgetReceiver';

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static Future<void> init() async {
    if (!_supported) return;
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Writes today's todos grouped by category to shared storage and triggers redraw.
  static Future<void> update({required List<Todo> todayTodos}) async {
    if (!_supported) return;

    // Group by category, only scheduled + not completed
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final t in todayTodos) {
      if (t.isCompleted) continue;
      grouped.putIfAbsent(t.category, () => []).add({
        'id': t.id,
        'title': t.title,
        'isDone': t.status == TodoStatus.done,
        'estimatedMinutes': t.estimatedMinutes,
      });
    }

    await HomeWidget.saveWidgetData<String>('todos_json', jsonEncode(grouped));
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
    );
  }
}
