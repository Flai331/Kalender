import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../db/app_database.dart';
import '../models/calendar_event.dart';
import '../models/todo.dart';
import '../widgets/conflict_dialog.dart';
import 'local_service.dart';
import 'supabase_service.dart';

class SyncService {
  static StreamSubscription<List<ConnectivityResult>>? _sub;
  static bool _syncing = false;
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
        try {
          await _processEntry(entry);
          await LocalService.removeFromQueue(entry.id);
        } catch (_) {
          // Leave in queue — will retry next sync
        }
      }
    } finally {
      _syncing = false;
    }
  }

  static Future<void> _processEntry(SyncQueueData entry) async {
    final table = entry.targetTable; // NOTE: targetTable, not tableName
    final op = entry.operation;

    // Guard against malformed payload — drop entry rather than infinite retry
    final dynamic decoded = jsonDecode(entry.payload);
    if (decoded is! Map<String, dynamic>) return;
    final payload = decoded;

    if (op == 'delete') {
      if (table == 'calendar_events') {
        await SupabaseService.deleteEvent(entry.entityId);
      } else {
        await SupabaseService.deleteTodo(entry.entityId);
      }
      return;
    }

    // upsert — detect conflict by comparing JSON payloads
    if (table == 'calendar_events') {
      final serverRow = await SupabaseService.getEventById(entry.entityId);
      if (serverRow != null) {
        final local = CalendarEvent.fromJson(payload);
        final serverJson = serverRow.toJson();
        final localJson = local.toJson();
        // Conflict: server has different data than what we're about to write
        if (serverJson.toString() != localJson.toString()) {
          final choice = await _askConflict(
            local.title,
            _eventSummary(local),
            _eventSummary(serverRow),
          );
          if (choice != ConflictChoice.keepLocal) return;
        }
      }
      await SupabaseService.saveEvent(CalendarEvent.fromJson(payload));
    } else {
      final serverRow = await SupabaseService.getTodoById(entry.entityId);
      if (serverRow != null) {
        final local = Todo.fromJson(payload);
        final serverJson = serverRow.toJson();
        final localJson = local.toJson();
        if (serverJson.toString() != localJson.toString()) {
          final choice = await _askConflict(
            local.title,
            _todoSummary(local),
            _todoSummary(serverRow),
          );
          if (choice != ConflictChoice.keepLocal) return;
        }
      }
      await SupabaseService.saveTodo(Todo.fromJson(payload));
    }
  }

  static String _eventSummary(CalendarEvent e) {
    final start = '${e.startTime.hour.toString().padLeft(2, '0')}:${e.startTime.minute.toString().padLeft(2, '0')}';
    return '${e.title} – $start';
  }

  static String _todoSummary(Todo t) {
    final status = t.status.name;
    return '${t.title} ($status, ${t.estimatedMinutes} Min)';
  }

  static Future<ConflictChoice> _askConflict(
      String title, String local, String server) async {
    final ctx = navigatorKey?.currentContext;
    if (ctx == null) return ConflictChoice.keepLocal;
    return await ConflictDialog.show(ctx,
        entityTitle: title, localSummary: local, serverSummary: server) ??
        ConflictChoice.keepLocal;
  }
}
