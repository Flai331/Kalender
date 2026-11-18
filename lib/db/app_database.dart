import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class EventsCache extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get data => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class TodosCache extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get data => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class AnnualEventsCache extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get data => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class SeriesRemindersCache extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get data => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class YearlyChecklistsCache extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get data => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class WeekNotesCache extends Table {
  // Schluessel ist der Wochenschluessel ("2026-W14"), nicht eine id.
  TextColumn get weekKey => text()();
  TextColumn get userId => text()();
  TextColumn get data => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {weekKey, userId};
}

/// Die Kategorien des Benutzers — EINE Zeile je Benutzer, die die ganze
/// geordnete Liste traegt.
///
/// Nicht eine Zeile je Kategorie: die Reihenfolge gehoert zur Liste, und
/// Anlegen, Umbenennen und Loeschen sind damit ein einziger Schreibvorgang,
/// der nicht halb ankommen kann.
class CategoriesCache extends Table {
  TextColumn get userId => text()();
  TextColumn get data => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {userId};
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityId => text()();
  TextColumn get targetTable => text()();
  TextColumn get operation => text()(); // 'upsert' | 'delete'
  TextColumn get payload => text()();
  IntColumn get createdAt => integer()();
}

@DriftDatabase(tables: [
  EventsCache,
  TodosCache,
  AnnualEventsCache,
  SeriesRemindersCache,
  YearlyChecklistsCache,
  WeekNotesCache,
  CategoriesCache,
  SyncQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Nur für Tests: erlaubt eine In-Memory-Datenbank statt der Datei.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2: Jahres-Events werden lokal zwischengespeichert, damit sie
          // auch offline gespeichert und angezeigt werden können.
          if (from < 2) {
            await m.createTable(annualEventsCache);
          }
          // v3: Serien-Erinnerungen und Jahres-Aufgaben ebenfalls lokal —
          // sonst werden Erinnerungen ohne Netz gar nicht erst eingeplant.
          if (from < 3) {
            await m.createTable(seriesRemindersCache);
            await m.createTable(yearlyChecklistsCache);
          }
          // v4: Wochennotizen und Wochenziele lokal — vorher gab es dafuer
          // gar keine Tabelle, sie liefen ausschliesslich ueber Supabase.
          if (from < 4) {
            await m.createTable(weekNotesCache);
          }
          // v5: Kategorien lokal — sie lagen in den Geraete-Einstellungen und
          // waren nach einer Neuinstallation weg, waehrend die Daten ihre
          // Schluessel behielten.
          if (from < 5) {
            await m.createTable(categoriesCache);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'kalender.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
