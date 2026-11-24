import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/models/todo_liste.dart';
import 'package:kalender/services/listen_service.dart';
import 'package:kalender/services/local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Listen und Ordner fuer die To-dos, wie bei Microsoft To Do: ein To-do
/// gehoert in genau eine Liste, mehrere Listen liegen in einem Ordner.
///
/// Geprueft wird vor allem, dass nie ein To-do unsichtbar wird: ohne Liste,
/// mit geloeschter Liste oder aus einer Sicherung von vorher steht es in der
/// Standardliste.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Todo todo(String id, {String? liste}) => Todo(
        id: id,
        title: id,
        createdAt: DateTime(2026, 1, 1),
        listeId: liste,
      );

  group('Modell', () {
    test('eine Liste ueberlebt den Weg durch JSON', () {
      const l = TodoListe(
          id: 'l1', name: 'Einkauf', ordner: 'Privat', farbe: 0xFF448AFF);
      final zurueck = TodoListe.fromJson(l.toJson());
      expect(zurueck, l);
      expect(zurueck!.imOrdner, isTrue);
    });

    test('ohne Ordner steht die Liste fuer sich', () {
      const l = TodoListe(id: 'l1', name: 'Einkauf', farbe: 1);
      expect(l.ordner, '');
      expect(l.imOrdner, isFalse);
    });

    test('kaputte Zeilen werden uebergangen, nicht geworfen', () {
      final liste = TodoListe.listFromJson(
          '[{"id":"a","name":"Gut","farbe":1},{"name":"ohne Id"},'
          '{"id":"c"},"Text",17]');
      expect(liste.map((l) => l.id), ['a']);
    });

    test('eine Liste ohne Farbe bekommt eine neutrale', () {
      final l = TodoListe.fromJson({'id': 'x', 'name': 'Ohne'});
      expect(l, isNotNull);
      expect(l!.farbe, 0xFF9E9E9E);
    });
  });

  group('Listen verwalten', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await LocalService.init(db);
      ListenService.resetForTesting();
      await ListenService.laden();
    });
    tearDown(() async => db.close());

    test('beim ersten Start gibt es genau die Standardliste', () async {
      expect(ListenService.alle.length, 1);
      expect(ListenService.alle.first.id, ListenService.standardId);
      expect(ListenService.alle.first.name, 'Aufgaben');
    });

    test('eine neue Liste steht hinter der Standardliste', () async {
      await ListenService.anlegen('Einkauf');
      expect(ListenService.alle.map((l) => l.name),
          ['Aufgaben', 'Einkauf']);
    });

    test('nach einem Neustart sind die Listen noch da', () async {
      final l = await ListenService.anlegen('Einkauf', ordner: 'Privat');
      ListenService.resetForTesting();
      await ListenService.laden();
      expect(ListenService.byId(l.id)?.name, 'Einkauf');
      expect(ListenService.byId(l.id)?.ordner, 'Privat');
    });

    test('umbenennen schlaegt bei leerem Namen fehl', () async {
      final l = await ListenService.anlegen('Einkauf');
      expect(await ListenService.umbenennen(l.id, '   '), isFalse);
      expect(ListenService.byId(l.id)?.name, 'Einkauf');
      expect(await ListenService.umbenennen(l.id, 'Markt'), isTrue);
      expect(ListenService.byId(l.id)?.name, 'Markt');
    });

    test('zwei Listen duerfen gleich heissen', () async {
      final a = await ListenService.anlegen('Einkauf', ordner: 'Privat');
      final b = await ListenService.anlegen('Einkauf', ordner: 'Arbeit');
      expect(a.id, isNot(b.id));
      expect(ListenService.alle.length, 3);
    });

    test('die Standardliste laesst sich nicht loeschen', () async {
      expect(await ListenService.loeschen(ListenService.standardId), isFalse);
      expect(ListenService.byId(ListenService.standardId), isNotNull);
    });

    test('sortieren verschiebt die Liste', () async {
      await ListenService.anlegen('Einkauf');
      await ListenService.anlegen('Haushalt');
      await ListenService.sortieren(2, 0);
      expect(ListenService.alle.map((l) => l.name),
          ['Haushalt', 'Aufgaben', 'Einkauf']);
    });

    test('revision zaehlt bei jeder Aenderung hoch', () async {
      final vorher = ListenService.revision.value;
      await ListenService.anlegen('Einkauf');
      expect(ListenService.revision.value, greaterThan(vorher));
    });
  });

  group('Ordner', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await LocalService.init(db);
      ListenService.resetForTesting();
      await ListenService.laden();
    });
    tearDown(() async => db.close());

    test('ein Ordner entsteht, wenn eine Liste ihn nennt', () async {
      expect(ListenService.ordner, isEmpty);
      final l = await ListenService.anlegen('Einkauf');
      await ListenService.inOrdner(l.id, 'Privat');
      expect(ListenService.ordner, ['Privat']);
      expect(ListenService.imOrdner('Privat').map((l) => l.name),
          ['Einkauf']);
    });

    test('die Ordner stehen in der Reihenfolge ihrer ersten Liste',
        () async {
      final a = await ListenService.anlegen('Einkauf', ordner: 'Privat');
      await ListenService.anlegen('Dienst', ordner: 'Arbeit');
      await ListenService.anlegen('Wäsche', ordner: 'Privat');
      expect(ListenService.ordner, ['Privat', 'Arbeit']);
      expect(a.ordner, 'Privat');
    });

    test('umbenennen fasst alle Listen des Ordners an', () async {
      await ListenService.anlegen('Einkauf', ordner: 'Privat');
      await ListenService.anlegen('Wäsche', ordner: 'Privat');
      expect(await ListenService.ordnerUmbenennen('Privat', 'Zuhause'),
          isTrue);
      expect(ListenService.ordner, ['Zuhause']);
      expect(ListenService.imOrdner('Zuhause').length, 2);
    });

    test('ein Ordner, den es nicht gibt, wird nicht umbenannt', () async {
      expect(await ListenService.ordnerUmbenennen('Nix', 'Doch'), isFalse);
    });

    test('aufloesen laesst die Listen stehen', () async {
      await ListenService.anlegen('Einkauf', ordner: 'Privat');
      expect(await ListenService.ordnerAufloesen('Privat'), isTrue);
      expect(ListenService.ordner, isEmpty);
      expect(ListenService.ohneOrdner.map((l) => l.name),
          ['Aufgaben', 'Einkauf']);
    });

    test('die letzte Liste heraus, und der Ordner ist weg', () async {
      final l = await ListenService.anlegen('Einkauf', ordner: 'Privat');
      await ListenService.inOrdner(l.id, '');
      expect(ListenService.ordner, isEmpty);
    });
  });

  group('To-dos und ihre Liste', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await LocalService.init(db);
      ListenService.resetForTesting();
      await ListenService.laden();
    });
    tearDown(() async => db.close());

    test('ein To-do ohne Liste steht in der Standardliste', () {
      expect(ListenService.echteListe(null), ListenService.standardId);
      expect(ListenService.nameOf(null), 'Aufgaben');
    });

    test('eine Liste, die es nicht gibt, zaehlt als Standardliste', () {
      expect(ListenService.echteListe('weg'), ListenService.standardId);
      expect(ListenService.nameOf('weg'), 'Aufgaben');
    });

    test('die Liste ueberlebt das Speichern', () async {
      final l = await ListenService.anlegen('Einkauf');
      await LocalService.saveTodo(todo('t1', liste: l.id));
      final zurueck = await LocalService.getAllTodos();
      expect(zurueck.single.listeId, l.id);
    });

    test('loeschen haengt die To-dos in die Standardliste um', () async {
      final l = await ListenService.anlegen('Einkauf');
      await LocalService.saveTodo(todo('t1', liste: l.id));
      await LocalService.saveTodo(todo('t2', liste: l.id));
      await LocalService.saveTodo(todo('t3'));

      expect(await LocalService.countInListe(l.id), 2);
      expect(await ListenService.loeschen(l.id), isTrue);

      final alle = await LocalService.getAllTodos();
      expect(alle.every((t) => t.listeId == null), isTrue);
      expect(alle.length, 3);
      expect(
          alle.every((t) =>
              ListenService.echteListe(t.listeId) ==
              ListenService.standardId),
          isTrue);
    });

    test('umhaengen laesst andere Listen in Ruhe', () async {
      final a = await ListenService.anlegen('Einkauf');
      final b = await ListenService.anlegen('Haushalt');
      await LocalService.saveTodo(todo('t1', liste: a.id));
      await LocalService.saveTodo(todo('t2', liste: b.id));

      expect(await LocalService.todosUmhaengen(a.id, b.id), 1);
      final alle = await LocalService.getAllTodos();
      expect(alle.every((t) => t.listeId == b.id), isTrue);
    });

    test('umhaengen auf dieselbe Liste tut nichts', () async {
      final a = await ListenService.anlegen('Einkauf');
      await LocalService.saveTodo(todo('t1', liste: a.id));
      expect(await LocalService.todosUmhaengen(a.id, a.id), 0);
    });

    test('eine Sicherung ohne Listen laesst die Standardliste entstehen',
        () async {
      await LocalService.seedTodoListen(const []);
      ListenService.resetForTesting();
      await ListenService.laden();
      expect(ListenService.alle.single.id, ListenService.standardId);
    });

    test('eine Sicherung ohne Standardliste bekommt sie dazu', () async {
      await LocalService.seedTodoListen(
          const [TodoListe(id: 'l1', name: 'Einkauf', farbe: 1)]);
      ListenService.resetForTesting();
      await ListenService.laden();
      expect(ListenService.alle.map((l) => l.id),
          [ListenService.standardId, 'l1']);
    });

    test('doppelte Kennungen werden auf eine eingedampft', () async {
      await LocalService.seedTodoListen(const [
        TodoListe(id: 'l1', name: 'Einkauf', farbe: 1),
        TodoListe(id: 'l1', name: 'Nochmal Einkauf', farbe: 2),
      ]);
      ListenService.resetForTesting();
      await ListenService.laden();
      expect(ListenService.alle.where((l) => l.id == 'l1').length, 1);
      expect(ListenService.byId('l1')?.name, 'Einkauf');
    });
  });
}
