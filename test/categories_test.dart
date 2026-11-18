import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/annual_event.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/services/category_service.dart';
import 'package:kalender/services/local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Die Kategorien waren vier englische Woerter, fest im Code, an vier Stellen
/// wiederholt. Jetzt gehoeren sie dem Benutzer: eigene Namen, eigene Farben,
/// eigene Liste.
///
/// Der Knackpunkt ist die Trennung von Schluessel und Name. In den Daten steht
/// der Schluessel; sichtbar ist der Name. Nur deshalb kann man eine Kategorie
/// umbenennen, ohne dass bestehende Termine ihre Zuordnung verlieren.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Die Liste liegt in der lokalen Datenbank, damit sie mitsynchronisiert
  // wird — jeder Test braucht daher eine eigene, leere.
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await LocalService.init(db);
    CategoryService.resetForTesting();
  });
  tearDown(() async => db.close());

  group('Vorgaben', () {
    test('ohne Einstellung gelten vier Kategorien auf Deutsch', () async {
      await CategoryService.load();
      expect(CategoryService.all.map((c) => c.label),
          ['Persönlich', 'Arbeit', 'Sport', 'Urlaub']);
    });

    test('die Schluessel sind die alten — Bestandsdaten bleiben zugeordnet',
        () async {
      await CategoryService.load();
      expect(CategoryService.keys, ['personal', 'work', 'sport', 'vacation']);
      expect(CategoryService.labelOf('work'), 'Arbeit');
      expect(CategoryService.labelOf('vacation'), 'Urlaub');
    });

    test('die Farben sind unveraendert', () async {
      await CategoryService.load();
      expect(CategoryService.colorValueOf('work'), 0xFF448AFF);
      expect(CategoryService.colorValueOf('personal'), 0xFFFF6D00);
    });
  });

  group('Anlegen und Aendern', () {
    test('eine neue Kategorie bekommt einen Schluessel aus dem Namen',
        () async {
      await CategoryService.load();
      final cat = await CategoryService.add('Ehrenamt', 0xFF00BCD4);
      expect(cat.key, 'ehrenamt');
      expect(cat.label, 'Ehrenamt');
      expect(CategoryService.colorValueOf('ehrenamt'), 0xFF00BCD4);
    });

    test('Umlaute und Leerzeichen werden im Schluessel aufgeloest', () {
      expect(CategoryService.slugify('Büro'), 'buero');
      expect(CategoryService.slugify('Haus & Garten'), 'haus_garten');
      expect(CategoryService.slugify('Straße'), 'strasse');
      // Ein Name ganz ohne brauchbare Zeichen darf keinen leeren Schluessel
      // ergeben.
      expect(CategoryService.slugify('???'), 'kategorie');
    });

    test('zwei gleiche Namen bekommen verschiedene Schluessel', () async {
      await CategoryService.load();
      final a = await CategoryService.add('Projekt', 0xFF448AFF);
      final b = await CategoryService.add('Projekt', 0xFFFF5252);
      expect(a.key, 'projekt');
      expect(b.key, 'projekt_2');
    });

    test('Umbenennen aendert den Namen, nicht den Schluessel', () async {
      await CategoryService.load();
      await CategoryService.update('work', label: 'Dienst');
      expect(CategoryService.labelOf('work'), 'Dienst');
      // Der Schluessel steht in den Daten — er darf sich nicht bewegen.
      expect(CategoryService.keys.contains('work'), isTrue);
      expect(CategoryService.exists('dienst'), isFalse);
    });

    test('die Farbe laesst sich aendern', () async {
      await CategoryService.load();
      await CategoryService.update('sport', colorValue: 0xFFE040FB);
      expect(CategoryService.colorValueOf('sport'), 0xFFE040FB);
      expect(CategoryService.labelOf('sport'), 'Sport');
    });

    test('die Reihenfolge laesst sich aendern', () async {
      await CategoryService.load();
      await CategoryService.move(3, 0);
      expect(CategoryService.keys.first, 'vacation');
      // Die erste ist die Vorgabe fuer neue Eintraege.
      expect(CategoryService.fallbackKey, 'vacation');
    });
  });

  group('Loeschen', () {
    test('eine Kategorie verschwindet aus der Liste', () async {
      await CategoryService.load();
      expect(await CategoryService.remove('sport'), isTrue);
      expect(CategoryService.keys, ['personal', 'work', 'vacation']);
    });

    test('die letzte Kategorie bleibt stehen', () async {
      await CategoryService.load();
      for (final key in ['work', 'sport', 'vacation']) {
        await CategoryService.remove(key);
      }
      expect(await CategoryService.remove('personal'), isFalse);
      expect(CategoryService.keys, ['personal']);
    });

    test('ein Schluessel, den es nicht mehr gibt, wird neutral angezeigt',
        () async {
      await CategoryService.load();
      await CategoryService.remove('sport');
      // Nicht die Farbe einer anderen Kategorie: sonst sieht ein verwaister
      // Eintrag aus, als gehoerte er irgendwo dazu.
      expect(CategoryService.colorValueOf('sport'),
          CategoryService.unknownColorValue);
      expect(CategoryService.labelOf('sport'), 'sport');
      expect(CategoryService.exists('sport'), isFalse);
    });
  });

  group('Speichern', () {
    test('Aenderungen ueberleben einen Neustart', () async {
      await CategoryService.load();
      await CategoryService.update('work', label: 'Dienst');
      await CategoryService.add('Ehrenamt', 0xFF00BCD4);

      CategoryService.resetForTesting();
      await CategoryService.load();

      expect(CategoryService.labelOf('work'), 'Dienst');
      expect(CategoryService.labelOf('ehrenamt'), 'Ehrenamt');
    });

    test('eine unlesbare alte Einstellung kostet nicht den Start', () async {
      SharedPreferences.setMockInitialValues(
          {'app_categories': 'kein json {{{'});
      await CategoryService.load();
      expect(CategoryService.keys, ['personal', 'work', 'sport', 'vacation']);
    });

    test('eine leere alte Liste faellt auf die Vorgaben zurueck', () async {
      SharedPreferences.setMockInitialValues({'app_categories': '[]'});
      await CategoryService.load();
      expect(CategoryService.all, isNotEmpty);
    });

    test('doppelte Schluessel werden zusammengelegt',
        () async {
      SharedPreferences.setMockInitialValues({
        'app_categories': jsonEncode([
          {'key': 'work', 'label': 'Arbeit', 'color': 0xFF448AFF},
          {'key': 'work', 'label': 'Doppelt', 'color': 0xFFFF5252},
        ])
      });
      await CategoryService.load();
      expect(CategoryService.keys, ['work']);
      expect(CategoryService.labelOf('work'), 'Arbeit');
    });
  });

  group('Gespeicherte Daten', () {
    test('die JSON-Form eines Termins bleibt unveraendert', () {
      final event = CalendarEvent(
        id: 'e1',
        title: 'Besprechung',
        startTime: DateTime(2026, 11, 18, 9),
        endTime: DateTime(2026, 11, 18, 10),
        category: 'work',
      );
      // Frueher stand hier category.name — derselbe Text. Deshalb braucht es
      // keine Wanderung der Bestandsdaten.
      expect(event.toJson()['category'], 'work');
    });

    test('ein alter Datensatz wird unveraendert gelesen', () {
      final json = {
        'id': 'e1',
        'title': 'Besprechung',
        'startTime': DateTime.utc(2026, 11, 18, 9).toIso8601String(),
        'endTime': DateTime.utc(2026, 11, 18, 10).toIso8601String(),
        'category': 'vacation',
      };
      expect(CalendarEvent.fromJson(json).category, 'vacation');
    });

    test('ein Datensatz ohne Kategorie faellt auf personal zurueck', () {
      final json = {
        'id': 'e1',
        'title': 'Besprechung',
        'startTime': DateTime.utc(2026, 11, 18, 9).toIso8601String(),
        'endTime': DateTime.utc(2026, 11, 18, 10).toIso8601String(),
      };
      expect(CalendarEvent.fromJson(json).category, 'personal');
    });

    test('eine Kategorie-Bedingung am To-do bleibt erhalten', () {
      final todo = Todo(
        id: 't1',
        title: 'Tanken',
        estimatedMinutes: 15,
        createdAt: DateTime(2026, 11, 18),
        requiredCategory: 'work',
      );
      expect(todo.toJson()['requiredCategory'], 'work');
      expect(Todo.fromJson(todo.toJson()).requiredCategory, 'work');
    });
  });

  group('Umhaengen beim Loeschen', () {
    setUp(() async => CategoryService.load());

    Future<void> bestand() async {
      await LocalService.saveTodo(Todo(
        id: 't1',
        title: 'Laufen',
        estimatedMinutes: 60,
        category: 'sport',
        createdAt: DateTime(2026, 11, 18),
      ));
      await LocalService.saveTodo(Todo(
        id: 't2',
        title: 'Schuhe kaufen',
        estimatedMinutes: 30,
        category: 'personal',
        requiredCategory: 'sport',
        createdAt: DateTime(2026, 11, 18),
      ));
      await LocalService.saveEvent(CalendarEvent(
        id: 'e1',
        title: 'Training',
        startTime: DateTime(2026, 11, 18, 18),
        endTime: DateTime(2026, 11, 18, 19),
        category: 'sport',
      ));
      await LocalService.saveAnnualEvent(AnnualEvent(
        id: 'a1',
        name: 'Marathon',
        category: 'sport',
        occurrences: [],
      ));
    }

    test('gezaehlt wird alles, was den Schluessel traegt', () async {
      await bestand();
      // Drei Eintraege plus die Bedingung am zweiten To-do.
      expect(await LocalService.countByCategory('sport'), 4);
      expect(await LocalService.countByCategory('vacation'), 0);
    });

    test('Umhaengen erfasst Eintraege und Bedingungen', () async {
      await bestand();
      final changed =
          await LocalService.reassignCategory('sport', 'personal');
      // Vier Datensaetze werden angefasst: die drei mit der Kategorie und das
      // To-do, dessen Bedingung auf sie zeigt.
      expect(changed, 4);

      final todos = await LocalService.getAllTodos();
      expect(todos.firstWhere((t) => t.id == 't1').category, 'personal');
      expect(
          todos.firstWhere((t) => t.id == 't2').requiredCategory, 'personal');
      // Die eigene Kategorie des zweiten To-dos war schon personal und darf
      // sich nicht veraendert haben.
      expect(todos.firstWhere((t) => t.id == 't2').category, 'personal');

      final events = await LocalService.getAllEvents();
      expect(events.single.category, 'personal');

      final annual = await LocalService.getAllAnnualEvents();
      expect(annual.single.category, 'personal');

      expect(await LocalService.countByCategory('sport'), 0);
    });

    test('Umhaengen auf dieselbe Kategorie macht nichts', () async {
      await bestand();
      expect(await LocalService.reassignCategory('sport', 'sport'), 0);
      expect(await LocalService.countByCategory('sport'), 4);
    });
  });
}
