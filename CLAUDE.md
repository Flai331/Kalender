# Kalender-App – Entwicklungsnotizen

## Fehleranalyse & Code-Überprüfung

1. Kritische Fehler (Sicherheit, Crashes) immer zuerst
2. Jeden Fehler mit Zeile, Erklärung und Fix ausgeben
3. Optimierungen mit Aufwand/Nutzen-Bewertung versehen
4. Abschluss: Gesamtbewertung 1–10 + Top-3-Maßnahmen
5. Vorher/Nachher-Beispiele für alle Vorschläge


## Architektur

Flutter-App, rein lokal: alle Daten liegen in einer SQLite-Datei auf dem
Gerät (drift). Kein Server, kein Konto. Hauptbereiche:
- `lib/week/` – Wochenansicht (week_screen.dart, week_day_column.dart, event_block.dart)
- `lib/todos/` – Todo-Verwaltung (todo_list_screen, todo_edit_screen, todo_status_dialog)
- `lib/models/` – Datenmodelle (todo.dart, calendar_event.dart, ics_source.dart)
- `lib/settings/` – Einstellungsscreen

## Features

### Wochenansicht (week_screen.dart)
- `_endHour = 24` — 23:00-Zeile sichtbar (nicht 23!)
- `_baseHourHeight` — veränderlich (nicht const), für Zoom
- Ctrl+Scroll = Zoom (Faktor 0.88/1.12, clamp 30–300 px/h)
  - `HardwareKeyboard.instance.addHandler(_onKey)` in initState, removeHandler in dispose
  - `_isCtrlPressed` → `NeverScrollableScrollPhysics()` blockiert Scrollen während Zoom
  - **Wichtig:** Listener muss INNEN in SingleChildScrollView (nicht außen!), sonst gewinnt ScrollView beim PointerSignalResolver
- Zeitachse (`_TimeAxis`): Unterteilungen abhängig von hourHeight (≥90→30min, ≥180→15min, ≥360→5min)
- Jetzt-Linie (`_NowLine`): LayoutBuilder muss Stack zurückgeben (nicht direkt Positioned — Positioned braucht Stack-Parent)
- Mehrtägige Events/Todos: overlap-basiertes Filtern (`startTime.isBefore(dayEnd) && endTime.isAfter(dayStart)`) + Clipping in Spalte
- Auto-Shift (`_autoShiftOverdueTodos`): nach Shift `setState(() => _initStreams())` für sofortiges UI-Update

### Auto-Shift-Logik
Verschiebt überfällige pending Todos automatisch nach vorne:
- **Fahrtzeiten**: `blockStart = scheduledStart - travelBefore`, `blockEnd = scheduledStart + estimatedMinutes + travelAfter`
- **Trigger**: `blockStart < nowMinutes`
- **Cascade-Stop**: gestartete/pausierte Todos werden nicht verschoben, setzen aber `runningMin = max(runningMin, blockEnd)` und resetten `shifted = false` → nachfolgende Todos werden nicht mehr gecascadet
- **Lücken erhalten**: Originalabstand zwischen pending Todos bleibt erhalten
- **Kalendereinträge überspringen**: `_skipEvents()` findet freie Zeitfenster

### Drag & Drop
- `LongPressDraggable` + `DragTarget`
- Während Drag: blaue Pill über Block zeigt "HH:MM – HH:MM" (via `currentTimeNotifier` + `ValueListenableBuilder`)
- `SnapState`: globale Klasse mit `snapNotifier`, `currentTimeNotifier`, `isDraggingNotifier`

### EventBlock (event_block.dart)
- `clipBehavior: Clip.hardEdge` — kein Overflow-Banner
- Zeitanzeige wenn `height >= 36`: "HH:MM – HH:MM" unter dem Titel
- Todos über Mitternacht: `(eh % 24)` für korrekte Endzeit (nicht 24:05 sondern 00:05)

### Todo-Modell (models/todo.dart)
- `dueWindowStartHour: int?`, `dueWindowEndHour: int?` — Erledigungszeitraum
- In copyWith (_unset-Pattern), toJson, fromJson

### Todo bearbeiten
- Status-Dialog: Chip "Bearbeiten" → `Navigator.pop(context, 'edit')`
- week_screen.dart + todo_list_screen.dart: `case 'edit' → Navigator.push(TodoEditScreen(todo: todo))`
- Todo-Edit-Screen: `_WindowPicker` + `_HourDrop` für Erledigungszeitraum (Von/Bis Dropdowns)

### Todo-Status-Dialog (todo_status_dialog.dart)
- `_timeInfo()`: zeigt "HH:MM – HH:MM · N Min" wenn scheduledStartHour gesetzt, sonst "N Min geplant"

## Bekannte Fallstricke

| Problem | Ursache | Fix |
|---------|---------|-----|
| Strg+Scroll scrollt trotzdem | Listener außen → ScrollView gewinnt PointerSignalResolver | Listener als Kind des ScrollView-Contents |
| Jetzt-Linie unsichtbar | Positioned direkt aus LayoutBuilder | LayoutBuilder gibt Stack zurück |
| 24:05 statt 00:05 | Fehlender Modulo bei Endzeit | `(eh % 24)` |
| Auto-Shift ohne Reload | Kein Stream-Refresh nach saveTodo | `setState(() => _initStreams())` |
| BOTTOM OVERFLOWED | EventBlock Column overflows | `clipBehavior: Clip.hardEdge` |
| IcsSource not found | Fehlender Import | `import '../models/ics_source.dart'` |
| Speichern-Knopf reagiert nicht mehr | `_saving = true` vor dem `await`, Exception (z.B. offline) → Flag wird nie zurückgesetzt | `try/finally` + `guardedAction()` aus `widgets/save_feedback.dart` |
| Speichern schlägt still fehl | `await …save…()` ohne try/catch — Nutzer sieht keine Meldung | `guardedAction()` zeigt SnackBar + schreibt ins Protokoll |
| Termin/Todo landet nicht in der Ansicht | Screen schreibt nicht über `LocalService` | `LocalService.saveEvent/saveTodo` (wie in `week_screen.dart`) |

## Datenhaltung (drift/SQLite)

Alle Daten liegen in `kalender.sqlite` im Dokumentenverzeichnis der App. Es
gibt **keinen Server**: schreibende Screens gehen über `LocalService`, lesende
über dessen Streams (`.watch()`), damit Gespeichertes sofort sichtbar ist.

Früher lag hinter der App ein Supabase-Projekt, mit `sync_queue`,
`SyncService`, `AuthService` und einem Konto-Bildschirm. Das ist alles raus
(Schema v6 wirft die Tabelle weg). Die App wird auf einem Gerät benutzt; was
gesichert werden soll, geht über `BackupService` in eine Datei.

**Neue Entität anlegen:**
1. Tabelle in `db/app_database.dart` anlegen, `schemaVersion` erhöhen und in
   `MigrationStrategy.onUpgrade` per `m.createTable(...)` ergänzen
2. `dart run build_runner build` (regeneriert `app_database.g.dart`)
3. `LocalService`: Stream + save/delete + seed ergänzen
   (`seed*` ist das Einspielen einer Sicherung, kein Serverabgleich)
4. `BackupService`: Feld in `build()` und `restore()` ergänzen, sonst fehlt die
   Entität in der Sicherung
5. Screens auf `LocalService` umstellen

Migrationen sind in `test/annual_events_offline_test.dart` getestet
(alte DB per rohem sqlite3 anlegen, dann `AppDatabase.forTesting(...)` öffnen).
Getestet werden v1→v2, v2→v3, v3→v4, v4→v5, v5→v6 und der Sprung v1→v6.

Aktueller Stand (Schema v6): `events_cache`, `todos_cache`,
`annual_events_cache`, `series_reminders_cache`, `yearly_checklists_cache`,
`week_notes_cache`, `categories_cache`.

Netz braucht die App nur für drei Dinge, alle ohne Konto:
- ICS-Abos (`IcsService`) und Outlook (`OutlookService`)
- Update-Prüfung über die GitHub-Releases (`UpdateService`)

## Benutzer-Kennung

Jede Zeile trägt eine `user_id`. Sie ist ein Überrest aus der Supabase-Zeit,
bleibt aber: ohne sie müssten alle sieben Tabellen migriert werden.

- `LocalService.init(db)` ist **async** und muss abgewartet werden: es legt
  eine Geräte-Kennung (`local-<uuid>`) in SharedPreferences an
- `_uid` ist diese Kennung. Ein leerer Wert wäre schlecht: er ließe die Daten
  nach einem Wechsel verwaisen
- Die Kennung steckt in der Sicherung **nicht** mit drin — beim Einspielen
  schreibt `restore()` alles auf die Kennung des Geräts, auf dem es landet

## Serien-Erinnerungen

`ReminderService.evaluateAll()` plant die Notifications. Aufgerufen wird sie
an zwei Stellen — beim App-Start (`main.dart`, nach Seeding) und nach dem
Speichern im `reminder_edit_screen`. Vorher existierte die Methode, wurde aber
nie aufgerufen: es wurde also nie eine Erinnerung eingeplant.

- `evaluateAll()` **wirft nie** — jede Erinnerung ist einzeln abgesichert,
  damit eine fehlschlagende (Outlook-Abfrage ohne Netz) die übrigen nicht
  verhindert; Fehler landen im Protokoll
- Beide Aufrufe sind `unawaited`: `outlook_service` setzt **keinen Timeout**,
  ein hängender Request würde sonst den App-Start blockieren
| PointerScrollEvent not found | Fehlende Imports | `flutter/gestures.dart` + `flutter/services.dart` |

## Imports week_screen.dart
```dart
import 'package:flutter/gestures.dart';   // PointerScrollEvent
import 'package:flutter/services.dart';   // HardwareKeyboard
import '../models/ics_source.dart';
import '../todos/todo_edit_screen.dart';
```

## Selbst-Update (wie in RHS Einsatz)

Vorlage: `suchgebiet_karten/android/.../Updater.kt` im Programmieren-Repo.
Dort läuft alles native und meldet an eine WebView. Hier ist es geteilt:

- **Dart** (`services/update_service.dart`): Prüfung über `version.json` aus
  dem Release, Download mit Fortschritt nach `<cache>/update/kalender.apk`
- **Native** (`android/.../Updater.kt`, Channel `com.example.kalender/updater`)
  nur, was native sein MUSS: `versionCode` der Installation, `verifyApk`
  (gültiges Paket, gleicher Paketname, höhere Version) und `install` über
  FileProvider

Nötig im Manifest: `REQUEST_INSTALL_PACKAGES` und der FileProvider mit
`${applicationId}.files`; der Pfad `update/` in `res/xml/file_paths.xml` muss
zum Download-Ziel passen.

**Android zeigt immer sein eigenes Installationsfenster** — eine App ohne
Systemrechte kann sich nicht still selbst installieren. Fehlt die Erlaubnis
"Unbekannte Apps installieren", gibt `install` "settings" zurück und die
Einstellung wird geöffnet.

Geladen wird nach `.part` und erst am Ende umbenannt: ein Abbruch hinterlässt
so keine halbe Datei, die der Installer annehmen könnte.

`installedBuild` kommt jetzt vom System (echter versionCode) und fällt nur auf
`kBuildNumber` zurück, wenn der Kanal nicht antwortet.
