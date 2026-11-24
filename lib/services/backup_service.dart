import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/annual_event.dart';
import '../models/app_category.dart';
import '../models/calendar_event.dart';
import '../models/place.dart';
import '../models/series_reminder.dart';
import '../models/todo.dart';
import '../models/todo_liste.dart';
import '../models/vorlage.dart';
import '../models/week_note.dart';
import '../models/yearly_checklist.dart';
import 'category_service.dart';
import 'local_service.dart';
import 'travel_service.dart';
import 'listen_service.dart';
import 'vorlagen_service.dart';

/// Was in einer Sicherung steckt — zum Anzeigen, bevor etwas passiert.
class BackupSummary {
  final DateTime? erstellt;
  final int termine;
  final int todos;
  final int jahresEvents;
  final int erinnerungen;
  final int jahresaufgaben;
  final int notizen;
  final int kategorien;
  final int orte;
  final int vorlagen;
  final int listen;
  final int einstellungen;

  const BackupSummary({
    required this.erstellt,
    required this.termine,
    required this.todos,
    required this.jahresEvents,
    required this.erinnerungen,
    required this.jahresaufgaben,
    required this.notizen,
    required this.kategorien,
    this.orte = 0,
    this.vorlagen = 0,
    this.listen = 0,
    required this.einstellungen,
  });

  /// Zeilen fuer die Rueckfrage. Leere Posten bleiben weg.
  List<String> get zeilen => [
        if (termine > 0) '$termine Termine',
        if (todos > 0) '$todos To-dos',
        if (jahresEvents > 0) '$jahresEvents Jahres-Events',
        if (erinnerungen > 0) '$erinnerungen Erinnerungen',
        if (jahresaufgaben > 0) '$jahresaufgaben Jahresaufgaben',
        if (notizen > 0) '$notizen Wochennotizen',
        if (kategorien > 0) '$kategorien Kategorien',
        if (orte > 0) '$orte Orte',
        if (vorlagen > 0) '$vorlagen Vorlagen',
        if (listen > 0) '$listen To-do-Listen',
        if (einstellungen > 0) '$einstellungen Einstellungen',
      ];
}

/// Ein automatisch geschriebener Stand, wie er im App-Ordner liegt.
class AutoSicherung {
  final String pfad;
  final DateTime datum;
  final int bytes;

  const AutoSicherung({
    required this.pfad,
    required this.datum,
    required this.bytes,
  });

  String get datumKurz =>
      '${datum.day.toString().padLeft(2, '0')}.'
      '${datum.month.toString().padLeft(2, '0')}.${datum.year}';

  String get groesseKurz => bytes < 1024
      ? '$bytes B'
      : (bytes < 1024 * 1024
          ? '${(bytes / 1024).round()} KB'
          : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB');
}

/// Eine Sicherung ist eine einzige Datei mit allem drin.
///
/// Die App speichert auf dem Geraet. Geht das Geraet kaputt, ist alles weg —
/// es sei denn, es liegt eine Datei woanders. Genau dafuer ist das hier: ein
/// Stand zum Weglegen, den man ohne die App lesen kann, weil es schlichtes
/// JSON ist.
///
/// Was NICHT mitgeht: die Zugangsdaten fuer Outlook. Die liegen im
/// verschluesselten Speicher des Geraets und haetten in einer Datei, die man
/// per Mail verschickt, nichts verloren. Nach dem Einspielen meldet man sich
/// dort einmal neu an.
class BackupService {
  /// Steht in der Datei. Aendert sich das Format, kann eine neue App eine
  /// alte Datei immer noch lesen — und eine alte App merkt, dass sie eine zu
  /// neue Datei vor sich hat.
  static const int formatVersion = 1;

  static const String _kennung = 'kalender';

  /// Einstellungen, die zum Geraet gehoeren und nicht zum Benutzer. Sie
  /// wandern bewusst nicht mit: die Kennung des Geraets und die alten
  /// Merkmale aus der Zeit mit Server, welche Tabellen schon geladen waren.
  static const Set<String> _internal = {
    'local_device_user_id',
    'local_seeded',
    'local_seeded_annual',
    'local_seeded_reminders',
    'local_seeded_notes',
    'local_seeded_categories',
    'app_categories',
  };

  // ── Erstellen ─────────────────────────────────────────────────────────────

  /// Baut die Sicherung als JSON-Text.
  static Future<String> build() async {
    final daten = <String, dynamic>{
      'app': _kennung,
      'format': formatVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'events': (await LocalService.getAllEvents())
          .map((e) => e.toJson())
          .toList(),
      'todos':
          (await LocalService.getAllTodos()).map((t) => t.toJson()).toList(),
      'annualEvents': (await LocalService.getAllAnnualEvents())
          .map((a) => a.toJson())
          .toList(),
      'reminders':
          (await LocalService.getReminders()).map((r) => r.toJson()).toList(),
      'yearlyChecklists': (await LocalService.getYearlyChecklists())
          .map((y) => y.toJson())
          .toList(),
      'weekNotes': (await LocalService.getAllWeekNotes())
          .map((n) => n.toJson())
          .toList(),
      'categories':
          (await LocalService.getCategories() ?? CategoryService.all)
              .map((c) => c.toJson())
              .toList(),
      'places':
          (await LocalService.getPlaces()).map((p) => p.toJson()).toList(),
      'vorlagen':
          (await LocalService.getVorlagen()).map((v) => v.toJson()).toList(),
      'todoListen': (await LocalService.getTodoListen())
          .map((l) => l.toJson())
          .toList(),
      'settings': await _settings(),
    };
    return const JsonEncoder.withIndent('  ').convert(daten);
  }

  /// Vorschlag fuer den Dateinamen: mit Datum, damit mehrere Staende
  /// nebeneinander liegen koennen.
  static String dateiname([DateTime? jetzt]) {
    final d = jetzt ?? DateTime.now();
    String zwei(int n) => n.toString().padLeft(2, '0');
    return 'kalender-sicherung-${d.year}-${zwei(d.month)}-${zwei(d.day)}.json';
  }

  /// Laesst den Benutzer waehlen, wohin die Sicherung geschrieben wird.
  ///
  /// Gibt den Pfad zurueck, oder null, wenn abgebrochen wurde.
  static Future<String?> saveToFile() async {
    final text = await build();
    final pfad = await FilePicker.platform.saveFile(
      dialogTitle: 'Sicherung speichern',
      fileName: dateiname(),
      bytes: Uint8List.fromList(utf8.encode(text)),
    );
    if (pfad != null) await _merkeZeitpunkt(_manuellKey);
    return pfad;
  }

  // ── Automatische Sicherung ────────────────────────────────────────────────
  //
  // Die App speichert nur auf dem Geraet. Bisher entstand eine Sicherung nur,
  // wenn man selbst daran dachte — und wer daran denkt, verliert auch nichts.
  // Deshalb schreibt die App ab jetzt selbst einmal am Tag einen Stand in
  // ihren eigenen Ordner und haelt die letzten paar vor.
  //
  // Das faengt den haeufigen Fall: aus Versehen geloescht, ein Import
  // daneben, eine Datenbank, die nicht mehr aufgeht. Es faengt NICHT das
  // verlorene Handy — dafuer braucht es weiter eine Datei, die woanders
  // liegt. Android nimmt den Ordner allerdings in seine eigene Sicherung
  // mit, wenn die eingeschaltet ist.

  static const String _autoKey = 'backup_auto_last';
  static const String _manuellKey = 'backup_manual_last';

  /// So viele automatische Staende bleiben liegen.
  static const int behalten = 5;

  static const String _ordnerName = 'sicherungen';

  /// Setzt den Ordner fuer Tests. Im Betrieb bleibt das null.
  static Directory? autoOrdnerFuerTests;

  static Future<Directory> _autoOrdner() async {
    final vorgabe = autoOrdnerFuerTests;
    if (vorgabe != null) {
      if (!await vorgabe.exists()) await vorgabe.create(recursive: true);
      return vorgabe;
    }
    final basis = await getApplicationDocumentsDirectory();
    final ordner = Directory('${basis.path}/$_ordnerName');
    if (!await ordner.exists()) await ordner.create(recursive: true);
    return ordner;
  }

  /// Schreibt einen Stand, hoechstens einen pro Tag.
  ///
  /// Gibt den Pfad zurueck, oder null, wenn heute schon einer liegt oder
  /// nichts zu sichern war. Wirft nicht nach oben durch — ein misslungener
  /// Versuch darf den Start der App nicht aufhalten.
  static Future<String?> autoSichern(
      {DateTime? jetzt, bool erzwingen = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = jetzt ?? DateTime.now();
      if (!erzwingen) {
        final letzte = DateTime.tryParse(prefs.getString(_autoKey) ?? '');
        if (letzte != null &&
            letzte.year == now.year &&
            letzte.month == now.month &&
            letzte.day == now.day) {
          return null;
        }
      }

      final text = await build();
      final vorhanden = await autoSicherungen();
      // Ein leerer Stand ueberschreibt nie einen gefuellten. Sonst waere die
      // automatische Sicherung genau dann wertlos, wenn man sie braucht:
      // nach dem Verlust steht in allen Staenden nichts mehr.
      if (_istLeer(summarize(parse(text))) && vorhanden.isNotEmpty) {
        return null;
      }

      final ordner = await _autoOrdner();
      final datei = File('${ordner.path}/${dateiname(now)}');
      await datei.writeAsString(text, flush: true);
      await _merkeZeitpunkt(_autoKey, now);
      await _aufraeumen();
      return datei.path;
    } catch (_) {
      return null;
    }
  }

  static bool _istLeer(BackupSummary inhalt) =>
      inhalt.termine == 0 &&
      inhalt.todos == 0 &&
      inhalt.notizen == 0 &&
      inhalt.jahresEvents == 0 &&
      inhalt.erinnerungen == 0 &&
      inhalt.jahresaufgaben == 0;

  /// Die vorhandenen automatischen Staende, der neueste zuerst.
  static Future<List<AutoSicherung>> autoSicherungen() async {
    final ordner = await _autoOrdner();
    final staende = <AutoSicherung>[];
    for (final eintrag in await ordner.list().toList()) {
      if (eintrag is! File || !eintrag.path.endsWith('.json')) continue;
      final stat = await eintrag.stat();
      staende.add(AutoSicherung(
        pfad: eintrag.path,
        datum: _datumAusNamen(eintrag.path) ?? stat.modified,
        bytes: stat.size,
      ));
    }
    staende.sort((a, b) => b.datum.compareTo(a.datum));
    return staende;
  }

  /// Liest einen Stand von der Platte — danach geht es weiter wie bei einer
  /// Datei, die man selbst ausgesucht hat.
  static Future<Map<String, dynamic>> leseStand(String pfad) async =>
      parse(await File(pfad).readAsString());

  /// Wann zuletzt automatisch gesichert wurde.
  static Future<DateTime?> letzteAuto() => _leseZeitpunkt(_autoKey);

  /// Wann zuletzt eine Datei aus der App heraus weggelegt wurde.
  static Future<DateTime?> letzteManuelle() => _leseZeitpunkt(_manuellKey);

  static Future<DateTime?> _leseZeitpunkt(String schluessel) async {
    final prefs = await SharedPreferences.getInstance();
    return DateTime.tryParse(prefs.getString(schluessel) ?? '');
  }

  static Future<void> _merkeZeitpunkt(String schluessel,
      [DateTime? jetzt]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        schluessel, (jetzt ?? DateTime.now()).toIso8601String());
  }

  static DateTime? _datumAusNamen(String pfad) {
    final name = pfad.split(Platform.pathSeparator).last;
    final treffer = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(name);
    if (treffer == null) return null;
    return DateTime(int.parse(treffer.group(1)!),
        int.parse(treffer.group(2)!), int.parse(treffer.group(3)!));
  }

  static Future<void> _aufraeumen() async {
    final staende = await autoSicherungen();
    if (staende.length <= behalten) return;
    for (final alt in staende.sublist(behalten)) {
      try {
        await File(alt.pfad).delete();
      } catch (_) {
        // Laesst sich ein alter Stand nicht loeschen, ist das kein Grund,
        // die neue Sicherung als gescheitert zu melden.
      }
    }
  }

  // ── Lesen und Einspielen ──────────────────────────────────────────────────

  /// Liest eine Datei, die der Benutzer aussucht.
  ///
  /// Gibt null zurueck, wenn er abbricht. Wirft [BackupFehler], wenn die
  /// Datei keine Sicherung dieser App ist.
  static Future<Map<String, dynamic>?> pickFile() async {
    final auswahl = await FilePicker.platform.pickFiles(withData: true);
    if (auswahl == null || auswahl.files.isEmpty) return null;
    final bytes = auswahl.files.first.bytes;
    if (bytes == null) {
      throw const BackupFehler('Die Datei liess sich nicht lesen.');
    }
    return parse(utf8.decode(bytes));
  }

  /// Prueft den Inhalt einer Sicherungsdatei.
  static Map<String, dynamic> parse(String text) {
    final dynamic roh;
    try {
      roh = jsonDecode(text);
    } catch (_) {
      throw const BackupFehler('Das ist keine Sicherungsdatei — kein JSON.');
    }
    if (roh is! Map<String, dynamic> || roh['app'] != _kennung) {
      throw const BackupFehler(
          'Das ist keine Sicherung vom Kalender.');
    }
    final format = (roh['format'] as num?)?.toInt() ?? 0;
    if (format > formatVersion) {
      throw BackupFehler(
          'Die Sicherung stammt aus einer neueren Version der App '
          '(Format $format, diese App kann $formatVersion). '
          'Erst die App aktualisieren.');
    }
    return roh;
  }

  static BackupSummary summarize(Map<String, dynamic> daten) {
    int zaehle(String schluessel) {
      final wert = daten[schluessel];
      return wert is List ? wert.length : 0;
    }

    final erstellt = DateTime.tryParse(daten['createdAt'] as String? ?? '');
    final einstellungen = daten['settings'];
    return BackupSummary(
      erstellt: erstellt,
      termine: zaehle('events'),
      todos: zaehle('todos'),
      jahresEvents: zaehle('annualEvents'),
      erinnerungen: zaehle('reminders'),
      jahresaufgaben: zaehle('yearlyChecklists'),
      notizen: zaehle('weekNotes'),
      kategorien: zaehle('categories'),
      orte: zaehle('places'),
      vorlagen: zaehle('vorlagen'),
      listen: zaehle('todoListen'),
      einstellungen: einstellungen is Map ? einstellungen.length : 0,
    );
  }

  /// Spielt die Sicherung ein. Ersetzt, was auf dem Geraet steht.
  static Future<void> restore(Map<String, dynamic> daten) async {
    List<Map<String, dynamic>> liste(String schluessel) {
      final wert = daten[schluessel];
      if (wert is! List) return const [];
      return wert.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }

    // Erst alles lesen und umwandeln, dann erst loeschen: eine kaputte Zeile
    // soll nicht dazu fuehren, dass die alten Daten schon weg sind.
    final events = liste('events').map(CalendarEvent.fromJson).toList();
    final todos = liste('todos').map(Todo.fromJson).toList();
    final annual = liste('annualEvents').map(AnnualEvent.fromJson).toList();
    final reminders = liste('reminders').map(SeriesReminder.fromJson).toList();
    final checklists =
        liste('yearlyChecklists').map(YearlyChecklist.fromJson).toList();
    final notes = liste('weekNotes').map(WeekNote.fromJson).toList();
    final categories = liste('categories')
        .map(AppCategory.fromJson)
        .whereType<AppCategory>()
        .toList();
    final places = liste('places').map(Place.fromJson).toList();
    final vorlagen = liste('vorlagen').map(Vorlage.fromJson).toList();
    final listen = liste('todoListen')
        .map(TodoListe.fromJson)
        .whereType<TodoListe>()
        .toList();

    await LocalService.clearAll();
    await LocalService.seedEvents(events);
    await LocalService.seedTodos(todos);
    await LocalService.seedAnnualEvents(annual);
    await LocalService.seedReminders(reminders);
    await LocalService.seedYearlyChecklists(checklists);
    await LocalService.seedWeekNotes(notes);
    if (categories.isNotEmpty) {
      await LocalService.seedCategories(categories);
    }
    await LocalService.seedPlaces(places);
    await LocalService.seedVorlagen(vorlagen);
    // Eine Sicherung von vor den Listen bringt keine mit. Dann bleibt die
    // Tabelle leer, und ListenService legt die Standardliste neu an —
    // die To-dos stehen alle darin, weil sie keine Liste nennen.
    if (listen.isNotEmpty) {
      await LocalService.seedTodoListen(listen);
    }

    final einstellungen = daten['settings'];
    if (einstellungen is Map) {
      await _restoreSettings(Map<String, dynamic>.from(einstellungen));
    }

    // Die Dienste halten ihren Stand im Speicher — ohne dieses Nachladen
    // zeigte die App die alten Kategorien und Fahrzeiten weiter.
    await TravelService.load();
    await CategoryService.load();
    await VorlagenService.neuLaden();
    await ListenService.neuLaden();
  }

  // ── Einstellungen ─────────────────────────────────────────────────────────

  /// Mit Typ, weil SharedPreferences zwischen Zahl, Text und Liste
  /// unterscheidet und JSON das beim Zurueckschreiben nicht mehr hergibt.
  static Future<Map<String, dynamic>> _settings() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (_internal.contains(key)) continue;
      final wert = prefs.get(key);
      if (wert is bool) {
        out[key] = {'typ': 'bool', 'wert': wert};
      } else if (wert is int) {
        out[key] = {'typ': 'int', 'wert': wert};
      } else if (wert is double) {
        out[key] = {'typ': 'double', 'wert': wert};
      } else if (wert is String) {
        out[key] = {'typ': 'string', 'wert': wert};
      } else if (wert is List<String>) {
        out[key] = {'typ': 'liste', 'wert': wert};
      }
    }
    return out;
  }

  static Future<void> _restoreSettings(Map<String, dynamic> daten) async {
    final prefs = await SharedPreferences.getInstance();
    for (final eintrag in daten.entries) {
      if (_internal.contains(eintrag.key)) continue;
      final wert = eintrag.value;
      if (wert is! Map) continue;
      final typ = wert['typ'];
      final inhalt = wert['wert'];
      try {
        switch (typ) {
          case 'bool':
            if (inhalt is bool) await prefs.setBool(eintrag.key, inhalt);
          case 'int':
            if (inhalt is num) await prefs.setInt(eintrag.key, inhalt.toInt());
          case 'double':
            if (inhalt is num) {
              await prefs.setDouble(eintrag.key, inhalt.toDouble());
            }
          case 'string':
            if (inhalt is String) await prefs.setString(eintrag.key, inhalt);
          case 'liste':
            if (inhalt is List) {
              await prefs.setStringList(
                  eintrag.key, inhalt.whereType<String>().toList());
            }
        }
      } catch (_) {
        // Eine einzelne unlesbare Einstellung darf das Einspielen nicht
        // kippen — die Daten sind wichtiger.
      }
    }
  }
}

class BackupFehler implements Exception {
  final String nachricht;
  const BackupFehler(this.nachricht);

  @override
  String toString() => nachricht;
}
