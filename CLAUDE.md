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
- `lib/week/` – Kalender (week_screen.dart, week_day_column.dart, event_block.dart, month_grid.dart)
- `lib/todos/` – Todo-Verwaltung (todo_list_screen, todo_edit_screen, todo_status_dialog)
- `lib/models/` – Datenmodelle (todo.dart, calendar_event.dart, ics_source.dart)
- `lib/settings/` – Einstellungsscreen

## Features

### Wochenansicht (week_screen.dart)
- Drei Ansichten in einem Screen: `CalendarView.tag | woche | monat`.
  Umgeschaltet wird über das Menü in der Titelzeile, geblättert über die
  Pfeile **oder durch Wischen** (`_onSwipe`, Schwelle 120 px/s). Ein Schritt
  ist je nach Ansicht ein Tag, eine Woche oder ein Monat (`_navigate`)
- `_visibleStart` / `_visibleEnd` sind der Zeitraum der aktuellen Ansicht.
  Streams (`_initStreams`) und ICS-Laden (`_loadIcsEvents`) hängen daran —
  die Monatsansicht braucht mehr als eine Woche
- Tage **nie** mit `Duration(days: n)` rechnen, sondern mit `addDays` aus
  `month_grid.dart` (`DateTime(y, m, d + n)`). In der Nacht der Zeitumstellung
  hat ein Tag 23 oder 25 Stunden, `.add(Duration(days: 1))` landet dann wieder
  im selben Tag
- `_getWeekStart` normalisiert auf Mitternacht, sonst fehlen beim Öffnen am
  Nachmittag die Termine von heute morgen
- Monatsraster (`month_grid.dart`): immer ganze Wochen Mo–So, je Termin ein
  farbiger Balken (`monthEntryColor`: Kalenderfarbe sticht Kategorie),
  Tippen auf einen Tag öffnet die Tagesansicht
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

### To-do abhaken (event_block.dart)
- Der Haken im Block hakt mit einem Tipp ab, ein zweiter macht wieder auf.
  `Todo.markDone()` / `Todo.reopen()` — `reopen()` setzt **auch**
  `isCompleted: false`, sonst bleibt das To-do aus der Todo-Leiste und dem
  Homescreen-Widget verschwunden (beide filtern darauf)
- Der Platz entscheidet, wo der Haken sitzt: eine Tagesspalte der
  Wochenansicht ist am Handy nur ~52 px breit. In der Titelzeile blieben dort
  17 px Titel übrig. Also: breit (≥64 px) → Haken in der Titelzeile; schmal
  und ≥44 px hoch → eigene Zeile darunter, Uhrzeit weicht; schmal und kurz →
  gar kein Haken, es bleibt beim Status-Dialog
- Ohne Verschiebung des Zeitplans zeigt das Abhaken ein "Rückgängig"; mit
  Verschiebung nicht — die Folgetermine sind mitgewandert, ein halbes Zurück
  wäre schlimmer als keins
- `height: 1.15` an Titel und Uhrzeit: das Theme gibt 1.43 vor, womit die
  Titelzeile 17 px hoch war und im 20-Minuten-Block (15 px) unten abgeschnitten
  wurde — unsichtbar, weil `clipBehavior: Clip.hardEdge` sauber abschneidet

### Kalender-Abos (settings_screen.dart)
- Der Schalter je Zeile blendet den Kalender **ein und aus**
  (`IcsSource.visible`). Ausgeblendet wird er gar nicht erst geholt
  (`IcsService.fetchEvents`), bleibt aber mit Farbe und Einstellungen stehen.
  Bis 11/2026 hing an dieser Stelle `allowTodoDrop` — eine Einstellung, die
  nur ein Tooltip erklärte, den man am Handy nie sieht
- Farbe und "Todos hineinziehen" sitzen im Dialog hinter dem Namen
  (`_openCalendarOptions`)
- Neue Felder in `IcsSource` brauchen in `fromJson` einen Vorgabewert, der
  den Altbestand richtig stellt (`visible: … ?? true`)

### Wochennotizen (notes_screen.dart)
- Wochenziele sind **abhakbar** (`WeekGoal{text, done}`). Vorher stand dort
  ein totes "○"-Zeichen, das wie ein Kästchen aussah
- Der Haken speichert **sofort und still** (`_save(still: true)`) — und nimmt
  den gerade getippten Text mit, damit nichts verloren geht
- `WeekGoal.fromJson` nimmt auch eine blanke Zeichenkette: so lagen die Ziele
  bis 11/2026 in der Datenbank

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
- Im Raster liegt dabei ein gestrichelter Platzhalter an der Stelle, an der losgelassen wird → **Einfüge-Vorschau** (eigener Abschnitt unten)

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
| Plus-Knopf deckt das letzte To-do zu | Todo-Leiste als letztes Element der Body-Spalte; `endFloat` setzt den FAB an den Scaffold-Boden | Leiste in `bottomNavigationBar:` — dann hebt Flutter den FAB von selbst darüber, in der tatsächlichen Höhe |
| Ranzoomen beim Ziehen bleibt aus | `_onDragMove` setzte den Ruhe-Zähler bei **jeder** Regung zurück; ein Daumen zittert um 1–2 px | Erst ab `_zittergrenze` (8 px) als Bewegung zählen |
| Ranzoomen klappt gar nicht mehr, bis zum App-Neustart | Abgebrochener Zug ließ `SnapState` auf 1 Minute stehen; der nächste stand schon am Ende der Leiter | `SnapState.begin()` beim Start **jedes** Zuges, `stop()` an **jedem** Ende (auch `onDragEnd` der Todo-Leiste) |
| PointerScrollEvent not found | Fehlende Imports | `flutter/gestures.dart` + `flutter/services.dart` |
| Platzhalter beim Ziehen springt nicht mit, wenn die Leiter feiner rastet | Die Vorschau wurde nur in `onMove` gerechnet — die Leiter rastet aber auch, wenn der Finger stillsteht | Letzten Punkt merken (`_letzterPunkt`) und am `snapNotifier` hängen; dieselbe Rechnung füttert Vorschau, Zeit-Pille und Ablegen |
| Meldung kommt im alten Ton, obwohl die Stufe umgestellt wurde | Android übernimmt Wichtigkeit und Ton nur beim **Anlegen** des Kanals | Je Stufe ein eigener `channelId` (`abfahrt_dringend`, `abfahrt_alarm`, …) |
| Abfahrt-Meldung kommt zweimal, einmal zur alten Uhrzeit | Ein übernommener Abo-Termin liegt lokal **und** kommt weiter aus dem Abo | `IcsService.fetchEventsOhneUebernommene()` statt `fetchEvents()` |
| `exact_alarms_not_permitted` bricht die ganze Planung ab | Ab Android 14 ist `SCHEDULE_EXACT_ALARM` standardmäßig verweigert | `USE_EXACT_ALARM` im Manifest (gilt sofort) **und** Rückfall auf `inexactAllowWhileIdle` in `_stellen` |


## Was im Terminblock steht (`event_block.dart`)

Zuerst der Titel, darunter die **Dauer**, darunter die Uhrzeit — soweit der
Block hoch und breit genug ist. **Keine An- und Abfahrt im Text**: die stand
früher als "🚗07:40  08:00 – 09:00  🏠09:20" in einer Zeile und wurde in der
52 px schmalen Wochenspalte zu "🚗07:40 08…" — man las die Abfahrt statt des
Termins. Die Fahrzeiten stehen ohnehin als eigene Streifen über und unter dem
Block.

`EventBlock.dauerText` schreibt Viertelstunden als Bruch (`1½ Std`), weil
"1 Std 30 min" 50 px braucht und nur 37 px Platz sind. Krumme Reste gehen
ganz in Minuten (`80 min`) — lieber das als eine gerundete, also falsche
Stundenzahl. Nichts wird länger als acht Zeichen, dafür gibt es einen Test.

**Das Höhenbudget ist eng und muss stimmen.** Vom Block gehen ab: 1 px Rand
oben und unten, 1,5 px Rahmen oben und unten, dazu das Polster. Bei einem
24-px-Block bleiben 13 px — da passt nicht einmal die 13,8 px hohe
Titelzeile hinein, sie wurde unten angeschnitten. Darum:

- Polster 1 px statt 3 px, solange der Block unter 36 px ist
- Dauerzeile mit Zeilenhöhe 1.0 und in engen Blöcken 8 statt 9 px — diese
  1,4 px entscheiden darüber, ob der sehr häufige 30-Minuten-Termin seine
  Dauer zeigt
- Dauer ab 30 px, Uhrzeit ab 44 px und nur in breiten Spalten

Wer hier etwas ändert: **rendern und hinsehen.** Jede dieser Zahlen kommt aus
einem Bild, nicht aus Kopfrechnen, und ein Überlauf fällt sonst nicht auf —
der Block schneidet sauber ab (`Clip.hardEdge`).

## Datenhaltung (drift/SQLite)

Alle Daten liegen in `kalender.sqlite` im Dokumentenverzeichnis der App. Es
gibt **keinen Server**: schreibende Screens gehen über `LocalService`, lesende
über dessen Streams (`.watch()`), damit Gespeichertes sofort sichtbar ist.

Früher lag hinter der App ein Supabase-Projekt, mit `sync_queue`,
`SyncService`, `AuthService` und einem Konto-Bildschirm. Das ist alles raus
(Schema v6 wirft die Tabelle weg). Die App wird auf einem Gerät benutzt; was
gesichert werden soll, geht über `BackupService` in eine Datei.

Schema v7 bringt `places_cache`: eine Zeile je Benutzer mit der ganzen
Orts-Liste als JSON, wie bei den Kategorien — die Rangliste gehört zur Liste,
nicht zum einzelnen Ort. `CalendarEvent.placeGroup` brauchte **keine**
Migration, Termine liegen als JSON-Blob in `events_cache.data`.

Zeitraum-Abfragen (`eventsForRange`, `todosForRange`) nehmen alles mit, was in
den Zeitraum **hineinreicht**, nicht nur was darin beginnt — sonst fehlt eine
Reise über den Monatswechsel im zweiten Monat.

**Sicherung:** `BackupService.autoSichern()` läuft beim Start (aus `main`,
nicht awaited) und legt höchstens einmal am Tag einen Stand in
`<Dokumente>/sicherungen/` ab; die letzten `behalten = 5` bleiben liegen. Ein
leerer Stand überschreibt nie einen gefüllten — sonst wäre die Sicherung genau
dann wertlos, wenn man sie braucht. Das ersetzt die Datei, die man selbst
weglegt, **nicht**: mit dem Gerät ist auch der App-Ordner weg.

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
- ICS-Abos (`IcsService`) — auch die Outlook-Kalender kommen so herein,
  eine Anmeldung bei Microsoft gibt es nicht und braucht es nicht
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

## Orte mit Öffnungszeiten (lib/places/, place_service.dart)

Mehrere Fitnessstudios in einer **Gruppe**, je Gruppe eine **Rangliste**
(`Place.rank`, kleiner = lieber). Am Termin steht nur die Gruppe
(`CalendarEvent.placeGroup`) — **welcher Ort es wird, entscheidet die App
erst, wenn der Termin näher rückt**. Das war die ausdrückliche Vorgabe: beim
Anlegen weiß man noch nicht, wo man dann gerade ist und was offen hat.

- `OpeningHours` ist ein Fenster je Wochentag in Minuten ab Mitternacht.
  `toMinute` darf **über 1440** gehen (bis 1 Uhr nachts = 1500 am Vortag) —
  als zweiter Eintrag am Folgetag ginge die Nacht Sonntag→Montag verloren
- **Keine eingetragenen Zeiten heißt immer offen** (`Place.hasHours`), sonst
  wäre ein frisch angelegtes Studio für immer unsichtbar und die App meldete
  „keiner offen", obwohl drei Orte in der Liste stehen
- `PlaceService.suggest` sortiert: ganz offen → beim Start offen
  (`closesDuring`, „kann hin, muss früher raus") → zu; darunter die
  **Rangliste**. Die Entfernung steht nur daneben, sie sortiert nicht
- Die Entfernung ist **Luftlinie** (Haversine); ohne Koordinaten oder ohne
  eigenen Standort bleibt `distanceKm` null statt geraten zu werden
- Adresse → Koordinaten über `GeoService` (Paket `geocoding`, Geocoder des
  Geräts): **kein Schlüssel, kein Dienst im Netz**. Fehler kommen als
  `GeoFehler` mit einem anzeigbaren Satz
- `PlaceReminderService` plant die Meldung `leadMinutes` vor dem Termin
  (Vorgabe 90, einstellbar). `plan()` ist rein gerechnet und ohne Android
  prüfbar. Die Nutzlast trägt nur die Termin-Kennung — **welcher Ort**
  entscheidet sich erst beim Antippen, mit dem Standort von dann
- Antippen läuft über `ReminderService.onTap` → `main.dart` →
  `PlaceSuggestScreen`; beim **kalten Start** kommt der Rückruf nicht, dann
  liefert `ReminderService.startPayload()` die Nutzlast

## Nur zur Info (`CalendarEvent.infoOnly`, `IcsSource.infoOnly`)

Der Dienstplan eines anderen Menschen. So ein Termin **steht im Kalender und
nimmt an nichts teil**. Setzen kann man ihn an zwei Stellen: am eigenen
Termin im Bearbeiten-Bildschirm, oder für einen ganzen abonnierten Kalender
in den Einstellungen — dann erbt ihn jeder Termin daraus (`_parseIcs` reicht
`source.infoOnly` durch).

Wo er übersprungen wird — **jede Stelle, die rechnet, nicht nur malt**:

- `week_screen._dayBlockedByAllDay` — ein fremder Urlaub sperrt nicht den
  eigenen Tag
- `week_screen._timedEventsOnDay` — zählt nicht als belegte Zeit, also
  findet die Lückensuche sie weiterhin
- `week_screen._todoDropAllowed` — gibt für Info-Termine immer `true`
  zurück, ein To-do darf darauf
- `TravelService.resolve` — erzwingt 0/0, **vor** der Vererbungskette: auch
  ein eigener Wert am Termin und die Vorgabe des Kalenders werden übergangen
- `PlaceReminderService.plan` — meldet sich nicht
- `week_day_column._computeOverlapLayout` — nimmt nicht an der
  Überlappungs-Rechnung teil

Gezeichnet wird er **hinter** den eigenen Terminen, über die **volle
Spaltenbreite**, blasser und mit `Icons.person_outline` statt der Ortsnadel.
Das ist der Punkt: ein fremder 8-Stunden-Dienst würde sonst als Nachbar die
halbe Tagesspalte wegnehmen. Dafür baut `_buildEventBlocks` die Liste zweimal
durch (erst alle `infoOnly`, dann der Rest). Monatsraster und Ganztags-Streifen
blassen ebenso ab.

**Verschieben geht trotzdem** — ein fremder Dienstplan ändert sich. Der
Info-Block hängt an derselben `LongPressDraggable` wie jeder andere (geteilte
Vorschau: `_ziehVorschau`), bekommt aber **kein** `DragTarget<Todo>`: ein
To-do auf einen fremden Dienst zu legen ergibt nichts, es fällt durch auf das
Tagesraster und landet dort auf der Uhrzeit. An-/Abfahrt-Streifen bekommt er
auch keine, und im Dialog für importierte Termine fehlt der Knopf
„An-/Abfahrt" — `resolve()` erzwingt dort 0/0, der Dialog ginge ins Leere.

`CalendarEvent.adoptedAsOwn` macht aus einem importierten Termin einen
eigenen (Verschieben oder Bearbeiten eines Abo-Termins geht darüber).
**Die Feldliste steht im Modell, nicht in der Wochenansicht** — sie war
vorher in `_convertIcsToApp` und driftete: `infoOnly` fehlte, ein
verschobener fremder Dienst sperrte danach wieder den eigenen Tag.

**Kein Migrationsschritt** — die Termine liegen als JSON im Cache, fehlendes
`infoOnly` liest sich als `false`, Altbestand redet also weiter mit.

## Serien-Erinnerungen

`ReminderService.evaluateAll()` plant die Notifications. Aufgerufen wird sie
an zwei Stellen — beim App-Start (`main.dart`, nach Seeding) und nach dem
Speichern im `reminder_edit_screen`. Vorher existierte die Methode, wurde aber
nie aufgerufen: es wurde also nie eine Erinnerung eingeplant.

- `evaluateAll()` **wirft nie** — jede Erinnerung ist einzeln abgesichert,
  damit eine fehlschlagende (Kalenderabruf ohne Netz) die übrigen nicht
  verhindert; Fehler landen im Protokoll
- Beide Aufrufe sind `unawaited`, der Kalenderabruf darf weder den App-Start
  noch das Schließen des Bildschirms aufhalten
- Auslöser ist ein Termin aus den **ICS-Abos**, gesucht von
  `ReminderService.findEventOnDay`. Bis 11/2026 fragte das die
  Microsoft-Graph-API über `OutlookService` — die war nie eingerichtet
  (Platzhalter-Client-Id), also stand im Bildschirm immer "Kein Outlook
  verbunden" und keine Fallback-Regel konnte je greifen. `OutlookService` ist
  entfernt; `SeriesReminder.calendarSourceId` hält jetzt die Id der ICS-Quelle
  (alter JSON-Schlüssel `outlookCalendarId` wird noch gelesen)

## Einfüge-Vorschau beim Ziehen (`week/week_day_column.dart`)

Während ein To-do oder ein Termin über dem Raster hängt, steht dort ein
gestrichelter Kasten in der **tatsächlichen Dauer** des Gezogenen — mit der
Uhrzeit darin (`08:30 – 09:00`, in der schmalen Wochenspalte nur `08:30`).
Das ist die Antwort auf „wo landet das, wenn ich jetzt loslasse".

- Zustand ist ein `ValueNotifier<({int minute, int dauer})?>`. `null` heißt
  **hier landet gerade nichts** — kein Platzhalter. Dart-Records vergleichen
  sich von selbst, der Notifier meldet also nur echte Änderungen
- Gestrichelt, nicht gefüllt: ein zweiter satter Block sähe aus wie ein
  zweiter Termin. `_StrichRand` malt den Rand über `Path.computeMetrics()`
- Die Vorschau erscheint **erst nach der Schonzeit** (250 ms, `_acceptTimer`),
  mit der ein fremder Tag einen Zug annimmt. Damit ist die Schonzeit zum
  ersten Mal sichtbar, statt den Benutzer raten zu lassen
- `_gerasteteMinute()` rechnet **einmal** und versorgt Vorschau, Zeit-Pille
  und `_handleDrop`. Vorher rechnete das Ablegen eigenständig, und die Pille
  blieb nach einem Leiter-Schritt auf der alten Uhrzeit stehen
- **`DragTargetDetails.offset` ist die linke obere Ecke des gezogenen Bildes,
  nicht der Finger** (Finger minus Greifpunkt). In Tests muss der Greifpunkt
  deshalb aus der Geometrie kommen (`t.getRect(...)`), nicht geraten werden
- Weil die Leiter (30 → 15 → 5 → 1 Min.) auch rastet, wenn der Finger
  stillsteht, hängt die Spalte am `snapNotifier` und rechnet mit dem
  gemerkten letzten Punkt neu

Tests: `test/einfuegestelle_test.dart` (Spalte 300×360, 8–14 Uhr bei 60 px/h,
damit 1 px = 1 Minute ist).

## Ans Losfahren erinnern (`services/departure_reminder_service.dart`)

Meldet sich vor der **Abfahrt**, nicht vor dem Termin: wer um 8:00 anfangen
muss und 20 Minuten fährt, bekommt um 7:35 Bescheid (5 Minuten Vorlauf ist
die Vorgabe). Ohne Anfahrtszeit gibt es nichts loszufahren — keine Meldung.

- Einstellbar in den Einstellungen unter *Benachrichtigungen*: an/aus,
  Vorlauf (0 – 30 Min.) und **wie eindringlich** (`ReminderUrgency`:
  still / normal / dringend / wie ein Wecker)
- **Je Stufe ein eigener Android-Kanal.** Die Wichtigkeit eines Kanals steht
  ab seiner Anlage fest, Android ignoriert jede spätere Änderung. Darum
  `channelId(stufe) = 'abfahrt_<id>'` und nicht ein Kanal mit wechselnder
  Einstellung. Die Zuordnung Stufe → Android steht allein in
  `ReminderService.androidFuer()`
- *Wie ein Wecker* läuft über `AudioAttributesUsage.alarm`: die
  Benachrichtigungs-Lautstärke geht beim Stummschalten mit, die
  Alarm-Lautstärke nicht
- `plan()` ist **reine Rechnung** (Termine, To-dos, `now`, Vorlauf → Liste)
  und darum ohne Datenbank und ohne Android prüfbar. Minuten-Arithmetik statt
  `Duration`, damit die Zeitumstellung nicht die Uhrzeit verschiebt
- Gerechnet wird auf **aufgelösten** Terminen (`TravelService.resolveAll`):
  die Anfahrt eines importierten Termins steht am Kalender, nicht am Termin
- Abo-Termine kommen über `IcsService.fetchEventsOhneUebernommene()` —
  ein übernommener (verschobener) Abo-Termin liegt sonst doppelt vor und
  klingelt zweimal, einmal zur alten Uhrzeit
- Horizont 7 Tage (länger als beim Ortsvorschlag): wer übers Wochenende nicht
  in die App schaut, soll Montag trotzdem gewarnt werden
- `scheduleAll()` läuft nach **jedem** Speichern, Verschieben und Löschen,
  wirft nie und läuft immer nur einmal gleichzeitig (`_laeuft`/`_nochmal`).
  Die Abos werden dabei höchstens alle 15 Minuten neu geholt
- Gestellte Meldungen stehen in `departure_scheduled`; was beim nächsten
  Durchgang fehlt, wird abgesagt. Sonst klingelt ein gelöschter Termin weiter

Tests: `test/abfahrt_test.dart`.

### Weckgenau stellen

`ReminderService._stellen()` versucht `exactAllowWhileIdle` und fällt bei
`exact_alarms_not_permitted` auf `inexactAllowWhileIdle` zurück (einmal je
App-Lauf ins Protokoll). Das Manifest bringt `USE_EXACT_ALARM` mit — das Recht
für Kalender- und Weckerprogramme, das sofort gilt; `SCHEDULE_EXACT_ALARM`
müsste der Benutzer ab Android 14 erst erlauben. Ohne den Rückfall hätte eine
Verweigerung die ganze Planungsschleife abgebrochen.

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
