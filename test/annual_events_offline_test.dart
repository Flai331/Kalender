import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/annual_event.dart';
import 'package:sqlite3/sqlite3.dart';

/// Legt eine Datenbank im Schema-Stand v1 an (ohne annual_events_cache),
/// so wie sie auf einem Gerät liegt, das die App schon installiert hat.
Database _openV1Database() {
  final raw = sqlite3.openInMemory();
  raw.execute('''
    CREATE TABLE events_cache (
      id TEXT NOT NULL PRIMARY KEY,
      user_id TEXT NOT NULL,
      data TEXT NOT NULL,
      updated_at INTEGER NOT NULL);
  ''');
  raw.execute('''
    CREATE TABLE todos_cache (
      id TEXT NOT NULL PRIMARY KEY,
      user_id TEXT NOT NULL,
      data TEXT NOT NULL,
      updated_at INTEGER NOT NULL);
  ''');
  raw.execute('''
    CREATE TABLE sync_queue (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      entity_id TEXT NOT NULL,
      target_table TEXT NOT NULL,
      operation TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at INTEGER NOT NULL);
  ''');
  raw.execute('PRAGMA user_version = 1;');
  return raw;
}

void main() {
  late AppDatabase db;

  tearDown(() async => db.close());

  group('Schema-Migration v1 → v2', () {
    test('legt annual_events_cache auf einer bestehenden v1-DB an', () async {
      final raw = _openV1Database();
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));

      // Erzwingt den Migrationslauf.
      await db.customSelect('SELECT 1').get();

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toList();

      expect(tables, contains('annual_events_cache'));
      expect(raw.userVersion, 2);
      // Bestandsdaten-Tabellen bleiben erhalten.
      expect(tables, contains('events_cache'));
      expect(tables, contains('todos_cache'));
      expect(tables, contains('sync_queue'));
    });

    test('erhält vorhandene Todos beim Upgrade', () async {
      final raw = _openV1Database();
      raw.execute(
        "INSERT INTO todos_cache (id, user_id, data, updated_at) "
        "VALUES ('t1', 'u1', '{}', 1)",
      );
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      await db.customSelect('SELECT 1').get();

      final rows = raw.select('SELECT id FROM todos_cache');
      expect(rows.length, 1);
      expect(rows.first['id'], 't1');
    });
  });

  group('Jahres-Event offline speichern', () {
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    test('schreibt in den Cache und stellt einen Sync-Auftrag ein', () async {
      final event = AnnualEvent(
        id: 'a1',
        name: 'Urlaub Teneriffa',
        category: 'vacation',
        occurrences: [
          AnnualOccurrence(year: 2027, startDate: DateTime(2027, 6, 1)),
        ],
      );

      // Entspricht LocalService.saveAnnualEvent — ohne Supabase-Auth,
      // die im Test nicht initialisiert werden kann.
      await db.into(db.annualEventsCache).insertOnConflictUpdate(
            AnnualEventsCacheCompanion(
              id: Value(event.id),
              userId: const Value('u1'),
              data: Value(jsonEncode(event.toJson())),
              updatedAt: const Value(1),
            ),
          );
      await db.into(db.syncQueue).insert(SyncQueueCompanion(
            entityId: Value(event.id),
            targetTable: const Value('annual_events'),
            operation: const Value('upsert'),
            payload: Value(jsonEncode(event.toJson())),
            createdAt: const Value(1),
          ));

      final cached = await db.select(db.annualEventsCache).get();
      expect(cached.length, 1);

      final restored =
          AnnualEvent.fromJson(jsonDecode(cached.first.data) as Map<String, dynamic>);
      expect(restored.name, 'Urlaub Teneriffa');
      expect(restored.occurrences.single.year, 2027);
      expect(restored.occurrences.single.startDate, DateTime(2027, 6, 1));

      final queue = await db.select(db.syncQueue).get();
      expect(queue.single.targetTable, 'annual_events');
      expect(queue.single.operation, 'upsert');
    });
  });
}
