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

/// Datenbank im Schema-Stand v2 (mit annual_events_cache, ohne die
/// Erinnerungs-Tabellen) — der Stand nach dem vorherigen Update.
Database _openV2Database() {
  final raw = _openV1Database();
  raw.execute('''
    CREATE TABLE annual_events_cache (
      id TEXT NOT NULL PRIMARY KEY,
      user_id TEXT NOT NULL,
      data TEXT NOT NULL,
      updated_at INTEGER NOT NULL);
  ''');
  raw.execute('PRAGMA user_version = 2;');
  return raw;
}

/// Datenbank im Schema-Stand v3 (alles ausser den Wochennotizen) — der Stand
/// vor dem Offline-Umbau der Notizen.
Database _openV3Database() {
  final raw = _openV2Database();
  for (final t in ['series_reminders_cache', 'yearly_checklists_cache']) {
    raw.execute('''
      CREATE TABLE $t (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        data TEXT NOT NULL,
        updated_at INTEGER NOT NULL);
    ''');
  }
  raw.execute('PRAGMA user_version = 3;');
  return raw;
}

/// Datenbank im Schema-Stand v4 — der Stand vor dem Synchronisieren der
/// Kategorien, als sie noch in den Einstellungen des Geraets lagen.
Database _openV4Database() {
  final raw = _openV3Database();
  raw.execute('''
    CREATE TABLE week_notes_cache (
      week_key TEXT NOT NULL,
      user_id TEXT NOT NULL,
      data TEXT NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (week_key, user_id));
  ''');
  raw.execute('PRAGMA user_version = 4;');
  return raw;
}

/// Datenbank im Schema-Stand v5 — der Stand mit Supabase: alle Tabellen samt
/// der Warteschlange, die die Aenderungen zum Hochladen gesammelt hat.
Database _openV5Database() {
  final raw = _openV4Database();
  raw.execute('''
    CREATE TABLE categories_cache (
      user_id TEXT NOT NULL PRIMARY KEY,
      data TEXT NOT NULL,
      updated_at INTEGER NOT NULL);
  ''');
  raw.execute('PRAGMA user_version = 5;');
  return raw;
}

void main() {
  late AppDatabase db;

  tearDown(() async => db.close());

  group('Schema-Migration ab v1', () {
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
      expect(raw.userVersion, db.schemaVersion);
      // Bestandsdaten-Tabellen bleiben erhalten.
      expect(tables, contains('events_cache'));
      expect(tables, contains('todos_cache'));
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

  group('Schema-Migration ab v2', () {
    test('legt die Erinnerungs-Tabellen auf einer v2-DB an', () async {
      final raw = _openV2Database();
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      await db.customSelect('SELECT 1').get();

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toList();

      expect(tables, contains('series_reminders_cache'));
      expect(tables, contains('yearly_checklists_cache'));
      expect(tables, contains('annual_events_cache'));
      expect(tables, contains('week_notes_cache'));
      expect(raw.userVersion, db.schemaVersion);
    });

    test('v1 springt direkt auf v3 durch', () async {
      final raw = _openV1Database();
      raw.execute(
        "INSERT INTO events_cache (id, user_id, data, updated_at) "
        "VALUES ('e1', 'u1', '{}', 1)",
      );
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      await db.customSelect('SELECT 1').get();

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toList();

      expect(tables, contains('annual_events_cache'));
      expect(tables, contains('series_reminders_cache'));
      expect(tables, contains('yearly_checklists_cache'));
      expect(tables, contains('week_notes_cache'));
      expect(raw.userVersion, db.schemaVersion);
      // Bestandsdaten überleben den Sprung über zwei Versionen.
      expect(raw.select('SELECT id FROM events_cache').length, 1);
    });
  });

  group('Schema-Migration v3 → v4', () {
    test('legt week_notes_cache an und behaelt die Bestandsdaten', () async {
      final raw = _openV3Database();
      raw.execute(
        "INSERT INTO series_reminders_cache (id, user_id, data, updated_at) "
        "VALUES ('r1', 'u1', '{}', 1)",
      );
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      await db.customSelect('SELECT 1').get();

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toList();

      expect(tables, contains('week_notes_cache'));
      expect(raw.userVersion, db.schemaVersion);
      expect(raw.select('SELECT id FROM series_reminders_cache').length, 1);
    });
  });

  group('Schema-Migration v4 → v5', () {
    test('legt categories_cache an und behaelt die Bestandsdaten', () async {
      final raw = _openV4Database();
      raw.execute(
        "INSERT INTO week_notes_cache (week_key, user_id, data, updated_at) "
        "VALUES ('2026-W47', 'u1', '{}', 1)",
      );
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      await db.customSelect('SELECT 1').get();

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toList();

      expect(tables, contains('categories_cache'));
      expect(raw.userVersion, db.schemaVersion);
      expect(raw.select('SELECT week_key FROM week_notes_cache').length, 1);
    });

  });

  group('Schema-Migration v5 → v6', () {
    test('wirft sync_queue weg und behaelt die Bestandsdaten', () async {
      final raw = _openV5Database();
      raw.execute(
        "INSERT INTO week_notes_cache (week_key, user_id, data, updated_at) "
        "VALUES ('2026-W47', 'u1', '{}', 1)",
      );
      raw.execute(
        "INSERT INTO sync_queue "
        "(entity_id, target_table, operation, payload, created_at) "
        "VALUES ('t1', 'todos', 'upsert', '{}', 1)",
      );
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      await db.customSelect('SELECT 1').get();

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toList();

      // Ohne Server gibt es nichts hochzuladen. Die Auftraege, die noch in
      // der Schlange standen, fallen mit der Tabelle weg.
      expect(tables, isNot(contains('sync_queue')));
      expect(raw.userVersion, db.schemaVersion);
      expect(raw.select('SELECT week_key FROM week_notes_cache').length, 1);
    });

    test('eine v1-DB kommt in einem Lauf bis zum heutigen Stand durch',
        () async {
      final raw = _openV1Database();
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      await db.customSelect('SELECT 1').get();

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toList();

      expect(tables, contains('week_notes_cache'));
      expect(tables, contains('categories_cache'));
      expect(tables, contains('places_cache'));
      expect(tables, contains('vorlagen_cache'));
      expect(tables, isNot(contains('sync_queue')));
      expect(raw.userVersion, db.schemaVersion);
    });
  });

  group('Jahres-Event offline speichern', () {
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    test('schreibt in den Cache', () async {
      final event = AnnualEvent(
        id: 'a1',
        name: 'Urlaub Teneriffa',
        category: 'vacation',
        occurrences: [
          AnnualOccurrence(year: 2027, startDate: DateTime(2027, 6, 1)),
        ],
      );

      // Entspricht LocalService.saveAnnualEvent, nur mit fester Kennung.
      await db.into(db.annualEventsCache).insertOnConflictUpdate(
            AnnualEventsCacheCompanion(
              id: Value(event.id),
              userId: const Value('u1'),
              data: Value(jsonEncode(event.toJson())),
              updatedAt: const Value(1),
            ),
          );

      final cached = await db.select(db.annualEventsCache).get();
      expect(cached.length, 1);

      final restored =
          AnnualEvent.fromJson(jsonDecode(cached.first.data) as Map<String, dynamic>);
      expect(restored.name, 'Urlaub Teneriffa');
      expect(restored.occurrences.single.year, 2027);
      expect(restored.occurrences.single.startDate, DateTime(2027, 6, 1));
    });
  });
}
