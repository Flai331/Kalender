import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/app_category.dart';
import 'package:kalender/services/category_service.dart';
import 'package:kalender/services/local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Die Kategorien lagen in den Einstellungen des Geraets. Damit hiess eine
/// umbenannte Kategorie nur auf einem Geraet so, und nach einer
/// Neuinstallation war die Liste weg, waehrend die Termine ihre Schluessel
/// behielten — sie zeigten dann 'work' statt 'Arbeit'.
///
/// Jetzt liegt die Liste in der lokalen Datenbank und geht denselben Weg wie
/// Termine und Todos: eine Zeile je Benutzer, ein Sync-Auftrag je Aenderung.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await LocalService.init(db);
    CategoryService.resetForTesting();
  });
  tearDown(() async => db.close());

  Future<List<SyncQueueData>> auftraege() =>
      LocalService.getPendingQueue();

  group('Speichern in der Datenbank', () {
    test('eine Aenderung landet in der lokalen Zeile', () async {
      await CategoryService.load();
      await CategoryService.update('work', label: 'Dienst');

      final gespeichert = await LocalService.getCategories();
      expect(gespeichert, isNotNull);
      expect(gespeichert!.firstWhere((c) => c.key == 'work').label, 'Dienst');
    });

    test('ein Neustart liest die Liste aus der Datenbank', () async {
      await CategoryService.load();
      await CategoryService.add('Ehrenamt', 0xFF00BCD4);
      await CategoryService.remove('sport');

      CategoryService.resetForTesting();
      await CategoryService.load();

      expect(CategoryService.keys, ['personal', 'work', 'vacation', 'ehrenamt']);
      expect(CategoryService.labelOf('ehrenamt'), 'Ehrenamt');
    });

    test('die Reihenfolge ueberlebt den Neustart', () async {
      await CategoryService.load();
      await CategoryService.move(3, 0);

      CategoryService.resetForTesting();
      await CategoryService.load();

      expect(CategoryService.keys, ['vacation', 'personal', 'work', 'sport']);
    });
  });

  group('Sync-Auftraege', () {
    test('die blossen Vorgaben werden nicht hochgeladen', () async {
      await CategoryService.load();
      // Sonst ueberschriebe ein neues Geraet, das beim ersten Start offline
      // ist, die Liste auf dem Server mit den Vorgaben.
      expect(await auftraege(), isEmpty);
      expect(await LocalService.getCategories(), CategoryService.defaults);
    });

    test('eine Aenderung erzeugt einen Auftrag', () async {
      await CategoryService.load();
      await CategoryService.update('work', label: 'Dienst');

      final q = await auftraege();
      expect(q.length, 1);
      expect(q.first.targetTable, 'categories');
      expect(q.first.operation, 'upsert');
    });

    test('mehrere Aenderungen bleiben ein einziger Auftrag', () async {
      await CategoryService.load();
      await CategoryService.update('work', label: 'Dienst');
      await CategoryService.add('Ehrenamt', 0xFF00BCD4);
      await CategoryService.remove('sport');
      await CategoryService.move(0, 2);

      final q = await auftraege();
      expect(q.length, 1);
      // Der Auftrag traegt den letzten Stand, nicht den ersten.
      final items = AppCategory.listFromJson(jsonDecode(q.first.payload));
      expect(items!.map((c) => c.key), CategoryService.keys);
    });

    test('der Auftrag traegt die ganze Liste', () async {
      await CategoryService.load();
      await CategoryService.add('Ehrenamt', 0xFF00BCD4);

      final q = await auftraege();
      final items = AppCategory.listFromJson(jsonDecode(q.first.payload));
      expect(items!.length, 5);
      expect(items.last.label, 'Ehrenamt');
    });
  });

  group('Uebernahme der alten Einstellung', () {
    test('eine vorhandene Liste wird uebernommen und hochgeladen', () async {
      SharedPreferences.setMockInitialValues({
        'app_categories': jsonEncode([
          {'key': 'work', 'label': 'Dienst', 'color': 0xFF448AFF},
          {'key': 'hobby', 'label': 'Hobby', 'color': 0xFF69F0AE},
        ])
      });

      await CategoryService.load();

      expect(CategoryService.keys, ['work', 'hobby']);
      expect(await LocalService.getCategories(), hasLength(2));
      // Hochgeladen werden muss sie: der Server kennt sie noch nicht.
      expect(await auftraege(), hasLength(1));
    });

    test('die alte Einstellung wird danach entfernt', () async {
      SharedPreferences.setMockInitialValues({
        'app_categories': jsonEncode([
          {'key': 'hobby', 'label': 'Hobby', 'color': 0xFF69F0AE},
        ])
      });

      await CategoryService.load();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_categories'), isNull);
    });

    test('die Datenbank hat Vorrang vor der alten Einstellung', () async {
      await LocalService.seedCategories(const [
        AppCategory(key: 'db', label: 'Aus der Datenbank', colorValue: 0xFF000000),
      ]);
      SharedPreferences.setMockInitialValues({
        'app_categories': jsonEncode([
          {'key': 'alt', 'label': 'Aus den Einstellungen', 'color': 0xFF111111},
        ])
      });

      await CategoryService.load();

      expect(CategoryService.keys, ['db']);
    });
  });

  group('Kaputtes Gespeichertes', () {
    Future<void> schreibeRoh(String data) async {
      await db.into(db.categoriesCache).insertOnConflictUpdate(
            CategoriesCacheCompanion(
              userId: Value(LocalService.currentUid),
              data: Value(data),
              updatedAt: const Value(1),
            ),
          );
    }

    test('unlesbarer Inhalt faellt auf die Vorgaben zurueck', () async {
      await schreibeRoh('[1,2,3]');
      await CategoryService.load();
      expect(CategoryService.keys, ['personal', 'work', 'sport', 'vacation']);
    });

    test('unbrauchbare Eintraege werden einzeln uebersprungen', () async {
      await schreibeRoh(jsonEncode({
        'items': [
          {'key': 'work', 'label': 'Dienst', 'color': 0xFF448AFF},
          {'label': 'ohne Schluessel', 'color': 0xFF448AFF},
          'kein Objekt',
          {'key': 'hobby'},
        ]
      }));
      await CategoryService.load();

      expect(CategoryService.keys, ['work', 'hobby']);
      // Ohne Namen gilt der Schluessel, ohne Farbe das neutrale Grau.
      expect(CategoryService.labelOf('hobby'), 'hobby');
      expect(CategoryService.colorValueOf('hobby'),
          CategoryService.unknownColorValue);
    });
  });

  group('Form des Gespeicherten', () {
    test('ein Objekt mit items, kein nacktes Array', () async {
      // Der Sync-Auftrag traegt immer ein Objekt — ein Array wuerde beim
      // Hochladen verworfen.
      final json = AppCategory.listToJson(CategoryService.defaults);
      expect(json.keys, ['items']);
      expect(json['items'], hasLength(4));
      expect(AppCategory.listFromJson(json), CategoryService.defaults);
    });

    test('null bedeutet nichts gespeichert, nicht leere Liste', () async {
      expect(AppCategory.listFromJson(null), isNull);
      expect(AppCategory.listFromJson([]), isNull);
      expect(AppCategory.listFromJson({'items': []}), isEmpty);
    });
  });
}
