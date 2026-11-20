import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../supabase_config.dart';
import '../db/app_database.dart';
import '../models/calendar_event.dart';
import '../models/todo.dart';
import '../models/annual_event.dart';
import '../models/series_reminder.dart';
import '../models/yearly_checklist.dart';
import '../models/week_note.dart';
import '../models/app_category.dart';
import '../widgets/conflict_dialog.dart';
import 'category_service.dart';
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

  /// Holt den Serverstand in den lokalen Zwischenspeicher.
  ///
  /// Je Tabelle einmal, gemerkt in den Einstellungen des Geraets. Je Tabelle
  /// ein eigenes Merkmal, weil sie zu verschiedenen Zeiten dazukamen: eine
  /// bestehende Installation hat 'local_seeded' schon gesetzt und bekaeme die
  /// spaeteren sonst nie.
  ///
  /// [force] laedt alles erneut. Nach einer Anmeldung an einem anderen Konto
  /// gilt dessen Kennung, und der Zwischenspeicher ist fuer sie leer — ohne
  /// dieses erneute Laden stuende die App nach dem Kontowechsel vor nichts.
  static Future<void> seedFromServer({bool force = false}) async {
    if (!SupabaseConfig.isConfigured) return;
    final prefs = await SharedPreferences.getInstance();

    Future<void> step(String flag, Future<void> Function() load) async {
      if (!force && prefs.getBool(flag) == true) return;
      await load();
      await prefs.setBool(flag, true);
    }

    await step('local_seeded', () async {
      await LocalService.seedEvents(await SupabaseService.getAllEvents());
      await LocalService.seedTodos(await SupabaseService.getAllTodos());
    });
    await step('local_seeded_annual', () async {
      await LocalService.seedAnnualEvents(
          await SupabaseService.getAllAnnualEvents());
    });
    await step('local_seeded_reminders', () async {
      await LocalService.seedReminders(await SupabaseService.getReminders());
      await LocalService.seedYearlyChecklists(
          await SupabaseService.getYearlyChecklists());
    });
    await step('local_seeded_notes', () async {
      await LocalService.seedWeekNotes(await SupabaseService.getAllWeekNotes());
    });
    await step('local_seeded_categories', () async {
      // Ohne force nur holen, wenn lokal noch keine Liste steht: sonst
      // ueberschriebe der Serverstand gerade erst offline angelegte
      // Kategorien, deren Sync-Auftrag noch wartet. Nach einem Kontowechsel
      // gilt dagegen die Liste des angemeldeten Kontos.
      if (!force && await LocalService.getCategories() != null) return;
      final remote = await SupabaseService.getCategories();
      if (remote != null && remote.isNotEmpty) {
        await LocalService.seedCategories(remote);
      }
    });

    // Die Kategorien stehen im Speicher des Dienstes, nicht nur in der
    // Datenbank — ohne dieses Nachladen zeigte die App nach einem erneuten
    // Laden weiter die alten Namen und Farben. Beim Start ist der Dienst
    // noch nicht geladen; dort kommt load() ohnehin gleich danach.
    if (CategoryService.isLoaded) await CategoryService.load();
  }

  static Future<void> _processEntry(SyncQueueData entry) async {
    final table = entry.targetTable; // NOTE: targetTable, not tableName
    final op = entry.operation;

    // Guard against malformed payload — drop entry rather than infinite retry
    final dynamic decoded = jsonDecode(entry.payload);
    if (decoded is! Map<String, dynamic>) return;
    final payload = decoded;

    // Unbekannte Tabellen NICHT als Todo behandeln — ein falsch geroutetes
    // delete/upsert würde sonst fremde Datensätze überschreiben oder löschen.
    const known = {
      'calendar_events',
      'todos',
      'annual_events',
      'series_reminders',
      'yearly_checklists',
      'week_notes',
      'categories',
    };
    if (!known.contains(table)) return;

    if (op == 'delete') {
      switch (table) {
        case 'calendar_events':
          await SupabaseService.deleteEvent(entry.entityId);
        case 'annual_events':
          await SupabaseService.deleteAnnualEvent(entry.entityId);
        case 'series_reminders':
          await SupabaseService.deleteReminder(entry.entityId);
        case 'yearly_checklists':
          await SupabaseService.deleteYearlyChecklist(entry.entityId);
        case 'week_notes':
          // Notizen werden nie geloescht, nur geleert — nichts zu tun.
          break;
        case 'categories':
          // Die Liste wird immer ganz geschrieben, nie geloescht.
          break;
        default:
          await SupabaseService.deleteTodo(entry.entityId);
      }
      return;
    }

    // Jahres-Events, Serien-Erinnerungen und Jahres-Aufgaben: kein
    // Conflict-Dialog — sie werden selten und nur auf einem Gerät bearbeitet,
    // ein Merge-Prompt wäre hier nur störend.
    switch (table) {
      case 'annual_events':
        await SupabaseService.saveAnnualEvent(AnnualEvent.fromJson(payload));
        return;
      case 'series_reminders':
        await SupabaseService.saveReminder(SeriesReminder.fromJson(payload));
        return;
      case 'yearly_checklists':
        await SupabaseService.saveYearlyChecklist(
            YearlyChecklist.fromJson(payload));
        return;
      case 'week_notes':
        await SupabaseService.saveWeekNote(WeekNote.fromJson(payload));
        return;
      case 'categories':
        final items = AppCategory.listFromJson(payload);
        // Unlesbar: Auftrag verwerfen statt ewig wiederholen.
        if (items != null) await SupabaseService.saveCategories(items);
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
