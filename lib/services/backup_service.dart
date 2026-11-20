import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/annual_event.dart';
import '../models/app_category.dart';
import '../models/calendar_event.dart';
import '../models/series_reminder.dart';
import '../models/todo.dart';
import '../models/week_note.dart';
import '../models/yearly_checklist.dart';
import 'category_service.dart';
import 'local_service.dart';
import 'travel_service.dart';

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
        if (einstellungen > 0) '$einstellungen Einstellungen',
      ];
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
    return FilePicker.platform.saveFile(
      dialogTitle: 'Sicherung speichern',
      fileName: dateiname(),
      bytes: Uint8List.fromList(utf8.encode(text)),
    );
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

    final einstellungen = daten['settings'];
    if (einstellungen is Map) {
      await _restoreSettings(Map<String, dynamic>.from(einstellungen));
    }

    // Die Dienste halten ihren Stand im Speicher — ohne dieses Nachladen
    // zeigte die App die alten Kategorien und Fahrzeiten weiter.
    await TravelService.load();
    await CategoryService.load();
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
