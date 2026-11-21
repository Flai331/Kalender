import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/services/backup_service.dart';
import 'package:kalender/services/category_service.dart';
import 'package:kalender/services/local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Eine Sicherung, die nur entsteht, wenn man selbst daran denkt, hilft genau
/// dem nicht, der sie braucht. Deshalb legt die App beim Start selbst einen
/// Stand ab und haelt die letzten paar vor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory ordner;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await LocalService.init(db);
    CategoryService.resetForTesting();
    await CategoryService.load();
    ordner = Directory.systemTemp.createTempSync('kalender-sicherung');
    BackupService.autoOrdnerFuerTests = ordner;
  });

  tearDown(() async {
    BackupService.autoOrdnerFuerTests = null;
    if (ordner.existsSync()) ordner.deleteSync(recursive: true);
    await db.close();
  });

  Future<void> bestand() async {
    await LocalService.saveEvent(CalendarEvent(
      id: 'e1',
      title: 'Besprechung',
      startTime: DateTime(2026, 11, 20, 9),
      endTime: DateTime(2026, 11, 20, 10),
      category: 'work',
    ));
    await LocalService.saveTodo(Todo(
      id: 't1',
      title: 'Tanken',
      estimatedMinutes: 15,
      createdAt: DateTime(2026, 11, 20),
      category: 'personal',
    ));
  }

  List<String> dateien() => ordner
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .toList()
    ..sort();

  group('Automatischer Stand', () {
    test('beim ersten Start entsteht eine Datei mit dem Datum im Namen',
        () async {
      await bestand();
      final pfad = await BackupService.autoSichern(jetzt: DateTime(2026, 11, 21));
      expect(pfad, isNotNull);
      expect(dateien(), ['kalender-sicherung-2026-11-21.json']);
    });

    test('der Stand enthaelt die Daten und laesst sich wieder lesen',
        () async {
      await bestand();
      final pfad =
          await BackupService.autoSichern(jetzt: DateTime(2026, 11, 21));
      final daten = await BackupService.leseStand(pfad!);
      final inhalt = BackupService.summarize(daten);
      expect(inhalt.termine, 1);
      expect(inhalt.todos, 1);
      expect(daten['app'], 'kalender');
    });

    test('ein zweiter Start am selben Tag schreibt nicht noch einmal',
        () async {
      await bestand();
      await BackupService.autoSichern(jetzt: DateTime(2026, 11, 21, 8));
      final zweiter =
          await BackupService.autoSichern(jetzt: DateTime(2026, 11, 21, 20));
      expect(zweiter, isNull);
      expect(dateien().length, 1);
    });

    test('am naechsten Tag entsteht ein neuer Stand', () async {
      await bestand();
      await BackupService.autoSichern(jetzt: DateTime(2026, 11, 21));
      await BackupService.autoSichern(jetzt: DateTime(2026, 11, 22));
      expect(dateien(), [
        'kalender-sicherung-2026-11-21.json',
        'kalender-sicherung-2026-11-22.json',
      ]);
    });

    test('es bleiben nur die letzten Staende liegen', () async {
      await bestand();
      for (int tag = 1; tag <= BackupService.behalten + 3; tag++) {
        await BackupService.autoSichern(
            jetzt: DateTime(2026, 1, tag), erzwingen: true);
      }
      final liste = dateien();
      expect(liste.length, BackupService.behalten);
      // Die aeltesten sind weg, der neueste ist da.
      expect(liste.first, 'kalender-sicherung-2026-01-04.json');
      expect(liste.last, 'kalender-sicherung-2026-01-08.json');
    });

    test('die Liste kommt mit dem neuesten Stand zuerst', () async {
      await bestand();
      await BackupService.autoSichern(
          jetzt: DateTime(2026, 11, 20), erzwingen: true);
      await BackupService.autoSichern(
          jetzt: DateTime(2026, 11, 21), erzwingen: true);
      final staende = await BackupService.autoSicherungen();
      expect(staende.first.datum, DateTime(2026, 11, 21));
      expect(staende.first.datumKurz, '21.11.2026');
      expect(staende.first.bytes, greaterThan(0));
      expect(staende.last.datum, DateTime(2026, 11, 20));
    });

    test('ein leerer Stand ueberschreibt keinen gefuellten', () async {
      await bestand();
      final erster =
          await BackupService.autoSichern(jetzt: DateTime(2026, 11, 20));
      final vorher = await File(erster!).readAsString();

      // Alles weg — genau der Moment, in dem die Sicherung zaehlt.
      await LocalService.clearAll();
      final zweiter = await BackupService.autoSichern(
          jetzt: DateTime(2026, 11, 21), erzwingen: true);

      expect(zweiter, isNull);
      expect(dateien(), ['kalender-sicherung-2026-11-20.json']);
      expect(await File(erster).readAsString(), vorher);
      expect((jsonDecode(vorher) as Map)['events'], hasLength(1));
    });

    test('auf einem leeren Geraet entsteht trotzdem ein erster Stand',
        () async {
      // Ohne vorhandenen Stand ist auch ein leerer besser als keiner: er
      // haelt die Kategorien und die Einstellungen.
      final pfad =
          await BackupService.autoSichern(jetzt: DateTime(2026, 11, 21));
      expect(pfad, isNotNull);
      expect(dateien().length, 1);
    });

    test('der Zeitpunkt des letzten Standes ist abfragbar', () async {
      await bestand();
      expect(await BackupService.letzteAuto(), isNull);
      await BackupService.autoSichern(jetzt: DateTime(2026, 11, 21, 7, 30));
      expect(await BackupService.letzteAuto(), DateTime(2026, 11, 21, 7, 30));
      // Die Datei, die man selbst weglegt, wird getrennt vermerkt.
      expect(await BackupService.letzteManuelle(), isNull);
    });

    test('aus einem Stand laesst sich der Bestand wiederherstellen', () async {
      await bestand();
      final pfad =
          await BackupService.autoSichern(jetzt: DateTime(2026, 11, 21));
      await LocalService.clearAll();
      expect(await LocalService.getAllEvents(), isEmpty);

      await BackupService.restore(await BackupService.leseStand(pfad!));

      final termine = await LocalService.getAllEvents();
      expect(termine, hasLength(1));
      expect(termine.first.title, 'Besprechung');
      expect(await LocalService.getAllTodos(), hasLength(1));
    });

    test('ein Fehler beim Schreiben bleibt still', () async {
      await bestand();
      // Ein Ordner, der nicht angelegt werden kann: der Pfad ist eine Datei.
      final blocker = File('${ordner.path}/blocker');
      blocker.writeAsStringSync('x');
      BackupService.autoOrdnerFuerTests = Directory(blocker.path);
      expect(await BackupService.autoSichern(jetzt: DateTime(2026, 11, 21)),
          isNull);
      BackupService.autoOrdnerFuerTests = ordner;
    });
  });
}
