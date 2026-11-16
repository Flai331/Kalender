import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';

/// Belegt, was passiert, wenn beim ersten Start keine Supabase-Sitzung
/// zustande kommt (frische Installation ohne Netz):
///
/// `LocalService._uid` liest `AuthService.userId`. Ohne Sitzung ist das null,
/// und `_uid` fällt auf '' zurück. Gespeichert wird dann unter dem leeren
/// Benutzer — und genau diese Zeilen findet die App nach einer späteren
/// Anmeldung nicht mehr, weil jede Abfrage auf die echte user_id filtert.
void main() {
  late AppDatabase db;

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

  Future<List<String>> idsForUser(String userId) async {
    final rows = await (db.select(db.todosCache)
          ..where((t) => t.userId.equals(userId)))
        .get();
    return rows.map((r) => r.id).toList();
  }

  test('offline ohne Sitzung angelegte Daten landen unter leerer user_id', () async {
    await insertTodo('t-offline', ''); // _uid == '' (kein Login moeglich)

    expect(await idsForUser(''), ['t-offline'],
        reason: 'die Zeile ist da — aber unter dem leeren Benutzer');
  });

  test('nach der Anmeldung sind diese Daten nicht mehr sichtbar', () async {
    await insertTodo('t-offline', ''); // offline angelegt
    await insertTodo('t-online', 'echte-uid-123'); // spaeter, angemeldet

    // Die App fragt ab der Anmeldung nur noch mit der echten user_id ab.
    expect(await idsForUser('echte-uid-123'), ['t-online']);
    expect(await idsForUser('echte-uid-123'), isNot(contains('t-offline')),
        reason: 'das offline angelegte Todo ist verwaist und verschwindet '
            'aus der Ansicht, obwohl es noch in der Datenbank liegt');

    // Es ist nicht geloescht — nur unerreichbar.
    final alle = await db.select(db.todosCache).get();
    expect(alle.length, 2);
  });
}
