import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';

/// Frische Installation ohne Netz: es kommt keine Supabase-Sitzung zustande.
/// Gespeichert wird dann unter einer Geräte-Kennung statt unter ''. Sobald
/// eine Sitzung existiert, schreibt LocalService.adoptLocalRows die Zeilen auf
/// die echte user_id um — sonst bliebe alles offline Angelegte unsichtbar.
///
/// Geprüft wird hier die SQL-Ebene von adoptLocalRows, ohne Supabase:
/// LocalService selbst braucht dafür eine Sitzung bzw. SharedPreferences.
void main() {
  late AppDatabase db;

  const geraet = 'local-abc-123';
  const echt = 'echte-uid-456';

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> insertTodo(String id, String userId) {
    return db.into(db.todosCache).insertOnConflictUpdate(
          TodosCacheCompanion(
            id: Value(id),
            userId: Value(userId),
            data: Value(jsonEncode({'id': id, 'title': 'Offline angelegt'})),
            updatedAt: const Value(1),
          ),
        );
  }

  Future<void> insertNote(String weekKey, String userId) {
    return db.into(db.weekNotesCache).insertOnConflictUpdate(
          WeekNotesCacheCompanion(
            weekKey: Value(weekKey),
            userId: Value(userId),
            data: Value(jsonEncode({'weekKey': weekKey, 'content': 'Notiz'})),
            updatedAt: const Value(1),
          ),
        );
  }

  Future<List<String>> todoIdsForUser(String userId) async {
    final rows = await (db.select(db.todosCache)
          ..where((t) => t.userId.equals(userId)))
        .get();
    return rows.map((r) => r.id).toList();
  }

  /// Dieselbe Anweisung, die adoptLocalRows je Tabelle ausführt.
  Future<int> adopt(String table, String from, String to) {
    return db.customUpdate(
      'UPDATE $table SET user_id = ? WHERE user_id = ?',
      variables: [Variable<String>(to), Variable<String>(from)],
      updates: const {},
    );
  }

  test('offline angelegte Todos sind nach der Übernahme sichtbar', () async {
    await insertTodo('t-offline', geraet);
    // Vor der Übernahme findet die Abfrage mit der echten Kennung nichts.
    expect(await todoIdsForUser(echt), isEmpty);

    final moved = await adopt('todos_cache', geraet, echt);

    expect(moved, 1);
    expect(await todoIdsForUser(echt), ['t-offline']);
    expect(await todoIdsForUser(geraet), isEmpty);
  });

  test('lässt Daten anderer Benutzer unberührt', () async {
    await insertTodo('t-offline', geraet);
    await insertTodo('t-fremd', 'andere-uid-999');

    await adopt('todos_cache', geraet, echt);

    expect(await todoIdsForUser(echt), ['t-offline']);
    expect(await todoIdsForUser('andere-uid-999'), ['t-fremd'],
        reason: 'nur Zeilen der Geräte-Kennung werden umgeschrieben');
  });

  test('erfasst auch die Wochennotizen (Schema v4)', () async {
    await insertNote('2026-W47', geraet);

    final moved = await adopt('week_notes_cache', geraet, echt);

    expect(moved, 1);
    final rows = await (db.select(db.weekNotesCache)
          ..where((n) => n.userId.equals(echt)))
        .get();
    expect(rows.single.weekKey, '2026-W47');
  });

  test('ist mehrfach ausführbar, ohne Schaden anzurichten', () async {
    await insertTodo('t-offline', geraet);

    final erst = await adopt('todos_cache', geraet, echt);
    final zweit = await adopt('todos_cache', geraet, echt);

    expect(erst, 1);
    expect(zweit, 0, reason: 'nach der Übernahme gibt es nichts mehr zu tun');
    expect(await todoIdsForUser(echt), ['t-offline']);
  });
}
