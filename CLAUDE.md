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
- **Kalendereinträge überspringen**: `Nachholen.hinterTermine()` findet freie Zeitfenster
- **Jetzt-Kante**: der Shift legt nichts vor `Nachholen.fruehestens(jetzt)` —
  fünf Minuten vor der aktuellen Uhrzeit, siehe *Liegengebliebenes nachholen*

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
- `requiredCategory: String?`, `requiredCalendarId: String?` — die Bindung an
  einen Termin (siehe „Nur im Termin")
- `listeId: String?` — die Liste, in der es steht (siehe „Listen und Ordner
  für To-dos"); `null` heisst Standardliste
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
| Sofortige Meldung kommt, geplante nicht | `show()` braucht keinen Wecker, `zonedSchedule` den ganzen Weg über AlarmManager, Empfänger und Kanal | *Wecker-Diagnose* in den Einstellungen — sie unterscheidet „nichts geplant" von „nichts gestellt" von „Kanal stumm" von „nur verschoben" |
| Probe nach 15 Sekunden bleibt aus, kommt aber später | Weckgenau nicht erlaubt → `inexactAllowWhileIdle`, Android bündelt und verschiebt | Weckweise des Test-Knopfs lesen; Recht unter Android → Apps → Kalender → „Weckerzeiten und Erinnerungen" |
| Ein kaputter Termin, und kein Wecker steht mehr | `_einmalPlanen` hatte **ein** try um die ganze Schleife | je Meldung ein eigenes try/catch |
| Kanal lauter stellen wirkt nicht | Wichtigkeit eines Kanals steht ab Anlage fest | je Stufe ein eigener `channelId` (`abfahrt_<id>`) |
| Diagnose stürzt ab, statt zu berichten | `getNotificationChannels()` wirft bei unbekannter Wichtigkeit; ohne Plattform wirft jeder Plugin-Aufruf | jede Nachfrage in `ReminderService` fängt selbst und gibt `null`/leer |
| Keine einzige geplante Meldung, `show()` geht | `tz.local` ist ein `late`-Feld ohne Vorgabe → `LateInitializationError` beim Rechnen des Zeitpunkts, falls `initializeTimeZones()` nicht lief (eigener Isolate, geänderte Startreihenfolge) | `ReminderService.zeitpunkt()` rechnet in `tz.UTC` — gleicher Moment, kein `late` |
| „Das Stellen schlägt fehl", aber wo? | Der Fehler von `zonedSchedule` landete nur im Protokoll | `diagnose()` macht einen echten Stellversuch und zeigt `PlatformException [code] Text` im Bericht |
| Termin/Todo landet nicht in der Ansicht | Screen schreibt nicht über `LocalService` | `LocalService.saveEvent/saveTodo` (wie in `week_screen.dart`) |
| To-do verschwindet nach dem Löschen einer Liste | `listeId` zeigt auf eine Liste, die es nicht mehr gibt | `ListenService.echteListe` fällt auf die Standardliste zurück; `loeschen` hängt zusätzlich wirklich um |
| „Neuer Ordner" legt nichts an | Ein Ordner ist nur der Name an seinen Listen — ohne Liste gibt es ihn nicht | Ordner im Menü einer Liste anlegen (`inOrdner`), nicht für sich |
| Schublade zeigt überall dieselbe Zahl | Gezählt wurde nach dem Filtern | Zahlen aus der **ungefilterten** Liste (`_anzahl(alle)`) |
| „A Timer is still pending" im Widget-Test | Beim Abmelden von einem drift-Stream läuft ein Null-Sekunden-Zeitgeber | Am Testende `pumpWidget(SizedBox.shrink())` + `pump(Duration.zero)` (siehe `test/todo_listen_screen_test.dart`) |
| `pumpAndSettle` läuft ewig | Der `StreamBuilder` zeigt noch den Kreisel, und der dreht sich endlos | Statt `pumpAndSettle` ein paar `pump(Duration(milliseconds: 20))` |
| ListTile-Farbe verschluckt den Tipp-Schatten | `ListTile` in einem gefärbten `Container` | `tileColor` am `ListTile` selbst |
| Plus-Knopf deckt das letzte To-do zu | Todo-Leiste als letztes Element der Body-Spalte; `endFloat` setzt den FAB an den Scaffold-Boden | Leiste in `bottomNavigationBar:` — dann hebt Flutter den FAB von selbst darüber, in der tatsächlichen Höhe |
| Ranzoomen beim Ziehen bleibt aus | `_onDragMove` setzte den Ruhe-Zähler bei **jeder** Regung zurück; ein Daumen zittert um 1–2 px | Erst ab `_zittergrenze` (8 px) als Bewegung zählen |
| Ranzoomen klappt gar nicht mehr, bis zum App-Neustart | Abgebrochener Zug ließ `SnapState` auf 1 Minute stehen; der nächste stand schon am Ende der Leiter | `SnapState.begin()` beim Start **jedes** Zuges, `stop()` an **jedem** Ende (auch `onDragEnd` der Todo-Leiste) |
| PointerScrollEvent not found | Fehlende Imports | `flutter/gestures.dart` + `flutter/services.dart` |
| Platzhalter beim Ziehen springt nicht mit, wenn die Leiter feiner rastet | Die Vorschau wurde nur in `onMove` gerechnet — die Leiter rastet aber auch, wenn der Finger stillsteht | Letzten Punkt merken (`_letzterPunkt`) und am `snapNotifier` hängen; dieselbe Rechnung füttert Vorschau, Zeit-Pille und Ablegen |
| Am Rand gezogen passiert nichts, obwohl der Sog eingebaut ist | `isDraggingNotifier` als Bedingung genommen — die geht erst an, wenn der Finger 600 ms ruht | `SnapState.zugLaeuft`, gesetzt in `begin()`/`stop()` |
| Die Ansicht läuft am Rand, die Zeit-Blase bleibt stehen | Ohne Fingerbewegung kommt kein `onMove`, die Vorschau rechnet also nicht neu | `nachziehen()` nach jedem Stück Lauf; die Spalte horcht auf `nachzugNotifier` |
| Beim Ranzoomen rutscht das Gezogene aus dem Bild | Der Zoom hielt die Viewport-Mitte fest; wer unten hält, verliert sein To-do nach unten | `Zoomanker.anker` nimmt während eines Zuges den Finger |
| Meldung kommt im alten Ton, obwohl die Stufe umgestellt wurde | Android übernimmt Wichtigkeit und Ton nur beim **Anlegen** des Kanals | Je Stufe ein eigener `channelId` (`abfahrt_dringend`, `abfahrt_alarm`, …) |
| Abfahrt-Meldung kommt zweimal, einmal zur alten Uhrzeit | Ein übernommener Abo-Termin liegt lokal **und** kommt weiter aus dem Abo | `IcsService.fetchEventsOhneUebernommene()` statt `fetchEvents()` |
| `exact_alarms_not_permitted` bricht die ganze Planung ab | Ab Android 14 ist `SCHEDULE_EXACT_ALARM` standardmäßig verweigert | `USE_EXACT_ALARM` im Manifest (gilt sofort) **und** Rückfall auf `inexactAllowWhileIdle` in `_stellen` |
| Geplante Meldungen kommen nie, der Test-Knopf geht | Die beiden Empfänger des Plugins fehlten im Manifest — AlarmManager stellt den Wecker, aber niemand nimmt ab; `show()` braucht keinen und ging deshalb | `ScheduledNotificationReceiver` + `ScheduledNotificationBootReceiver` ins Manifest, bewacht von `test/manifest_test.dart` |
| „Kein passender Slot in 30 Tagen", obwohl nächste Woche ein Termin ist | Die Suche las `_events`/`_icsEvents` — die halten nur die **angezeigte** Woche | `Planungsvorrat` aus Datenbank + Abo-Puffer, unabhängig von der Ansicht |
| To-do „nur im Termin" landet im Dienstplan eines anderen Menschen | Importierte Termine tragen alle `category: 'work'`, und „nur zur Info" wurde bei der Gastgeber-Suche nicht geprüft | `Terminbindung.passt` lässt Info-Termine nur bei ausdrücklich gewähltem Kalender zu |
| To-do findet nie einen Platz, Kalender sieht normal aus | Das gebundene Abo ist ausgeblendet oder entfernt — ausgeblendete Abos werden nicht geholt | Hinweis im To-do-Bildschirm; beim Entfernen löst `LocalService.loeseKalenderBindung` die Bindung |
| Nachgeholtes To-do liegt über dem Termin von heute | Der Carry-over nahm die Uhrzeit von gestern mit; lag sie heute noch in der Zukunft, fasste der Shift sie nicht mehr an (`blockStart < nowMinutes` war falsch) | `Nachholen.plan()` vergibt die Uhrzeit neu, ab der Jetzt-Kante und um die echten Termine herum |
| Gebundenes To-do bleibt stehen, wenn der Dienst verschoben wird, und klebt dann an der Jetzt-Linie | Es wurde erst beim Überfälligwerden neu geplant; auf einem Tag ohne Termin schob der Auto-Shift es stattdessen Minute für Minute mit | `_folgeDemTermin` prüft je Durchgang `Terminbindung.stehtIn` und sucht sofort den nächsten Gastgeber |
| Umbenannte Vorlage setzt weiter den alten Titel | `title` stand in `felder` **und** in `name` | `_gesiebt` wirft `title` weg, `aufTermin`/`aufTodo` setzen ihn aus `name` |
| Vorlage schleppt den Stand eines fremden Termins mit (gestartet, 7 Minuten Pause) | `felder` ist das ganze `toJson()` des Modells | Alles Einmalige gehört in `Vorlage._nurEinmalig` — bei jedem neuen Modell-Feld mitdenken |
| Vorschlagsliste erscheint beim ersten Antippen des leeren Feldes nicht | `RawAutocomplete` rechnet die Vorschläge erst, wenn der Text sich **ändert** | Gewollt: Vorschläge beim Tippen. Soll es anders sein, braucht es einen eigenen `OverlayPortal` |
| Vorlagen fehlen nach dem Einspielen einer Sicherung | `VorlagenService` hält die Liste im Speicher | `VorlagenService.neuLaden()` am Ende von `BackupService.restore`, wie `TravelService.load()` |
| Nachgeschobenes To-do hängt 5 Minuten hinter der Jetzt-Linie statt davor | `Nachholen.fruehestens` zog `vorlauf` **ab**, damit die Linie durch den Block schneidet | `jetzt + vorlauf`; ein Block, der schon läuft, sieht aus wie etwas Verpasstes |
| Jede **geplante** Meldung fällt im fertigen APK aus, im Debug läuft alles | Flutter schaltet R8 für jeden Release-Build selbst ein; R8 wirft die generischen Signaturen weg, und `flutter_local_notifications` legt seine Liste mit Gson ab → `TypeToken must be created with a type argument` | `android/app/proguard-rules.pro` (`-keepattributes Signature`, `TypeToken` behalten); Flutter hängt die Datei von allein an |
| Die erste Benachrichtigung kommt, die zweite nicht | `show()` braucht kein Gson, `zonedSchedule` schon. Der Unterschied ist nicht „sofort gegen später", sondern „ohne gegen mit Ablage" | Immer beides prüfen: eine sofortige **und** eine geplante Meldung. Nur die geplante sagt etwas aus |
| „Wecker insgesamt gestellt: 0", ohne dass je ein Fehler kam | `pendingNotificationRequests()` liest dieselbe Gson-Ablage, in die das Stellen schreibt. Der Lesefehler sah aus wie eine leere Liste | `geplanteKennungen()` gibt `Set<int>?`; `null` heißt **nicht feststellbar** und wird im Bericht so genannt |
| Gebundenes To-do springt zurück, nachdem man es von Hand danebengezogen hat | Es hat keinen Gastgeber mehr — genau das ist das Zeichen zum Neusuchen | Gewollt. Soll es stehen bleiben, muss es **fest** sein; feste To-dos fasst die App nie an |


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

Schema v8 bringt `vorlagen_cache`, genauso gebaut: eine Zeile je Benutzer mit
allen Vorlagen als JSON-Liste.

Schema v9 bringt `todo_listen_cache`, ebenso — die Reihenfolge der Listen
gehört zur Liste. `Todo.listeId` brauchte **keine** Migration, To-dos liegen
als JSON-Blob in `todos_cache.data`.

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

Aktueller Stand (Schema v9): `events_cache`, `todos_cache`,
`annual_events_cache`, `series_reminders_cache`, `yearly_checklists_cache`,
`week_notes_cache`, `categories_cache`, `places_cache`, `vorlagen_cache`,
`todo_listen_cache`.

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

## Listen und Ordner für To-dos (`models/todo_liste.dart`, `services/listen_service.dart`, `todos/listen_schublade.dart`)

Wie bei Microsoft To Do: **Ordner** enthalten **Listen**, Listen enthalten
To-dos. Ein To-do gehört in genau eine Liste (`Todo.listeId`).

**Die Standardliste** (`ListenService.standardId == 'aufgaben'`, „Aufgaben")
fängt alles auf: `listeId == null` *und* eine Kennung, die es nicht mehr gibt,
zählen beide dazu (`ListenService.echteListe`). Darum kann kein To-do
unsichtbar werden — nicht durch eine gelöschte Liste, nicht durch eine
Sicherung von vor den Listen. Sie lässt sich nicht löschen, und `_mitStandard`
setzt sie beim Laden wieder davor, wenn eine Sicherung sie nicht mitbringt.

**Ein Ordner ist nur ein Name** an seinen Listen (`TodoListe.ordner`), genau
wie `Place.group` bei den Orten — keine zweite Tabelle, keine zweite
Verwaltung. Folgen davon:
- Einen *leeren* Ordner gibt es nicht. „Neuer Ordner" steht darum nicht für
  sich, sondern im Menü einer Liste („In Ordner" → „Neuer Ordner …")
- Umbenennen fasst alle Listen des Ordners an (`ordnerUmbenennen`)
- Die letzte Liste heraus, und der Ordner ist weg
- `ordnerAufloesen` lässt die Listen stehen — in ihnen stecken die To-dos

**Die Reihenfolge** steckt in der Liste selbst, nicht als Zahl am Eintrag
(wie bei den Kategorien): `sortieren(alt, neu)` verschiebt. Die Ordner stehen
in der Reihenfolge ihrer ersten Liste.

**Löschen einer Liste** hängt ihre To-dos in die Standardliste um
(`LocalService.todosUmhaengen`) — gelöscht wird keines. Der Dialog nennt die
Zahl, bevor er fragt.

**Wo das sichtbar wird:**
- `todos/listen_schublade.dart` — die Seitenleiste: „Alle To-dos", die Listen
  ohne Ordner, dann die Ordner als aufklappbare Gruppen. Verwalten
  (umbenennen, Farbe, einordnen, löschen) über das `⋮` an der Zeile. Ein
  Stream für den ganzen Bildschirm, nicht nur für den Rumpf: die Schublade
  braucht dieselben To-dos für ihre Zahlen
- `todos/todo_list_screen.dart` — filtert auf die offene Liste, zeigt sie im
  Titel; in der Gesamtschau steht der Listenname an jeder Karte
  (`TodoCard.zeigeListe`)
- `widgets/listen_picker.dart` — die Auswahl im Formular, gebaut wie der
  `CategoryPicker`. Neue To-dos landen in der offenen Liste
  (`TodoEditScreen.listeId`)
- `week_screen.dart` — `_poolKopf`/`_poolFilter` filtern die Todo-Leiste,
  `_TodoChip` trägt einen Farbpunkt. **Beides erst ab zwei Listen**: wer nie
  eine zweite anlegt, sieht nichts Neues

Eine Vorlage trägt die Liste mit (`listeId` steht nicht in
`Vorlage._nurEinmalig`): „Milch holen" gehört immer in „Einkauf". Eine Vorlage
von *vor* den Listen nennt keine — dann bleibt die offene Liste stehen, statt
in die Standardliste zu rutschen (`felder.containsKey('listeId')`).

## Vorlagen (`models/vorlage.dart`, `services/vorlagen_service.dart`, `vorlagen/`)

„Dienst Spät" ist immer acht Stunden lang, hat 20 Minuten Anfahrt und zehn
zurück, Kategorie Arbeit. Das jedes Mal neu einzustellen ist Arbeit für
nichts — die Vorlage trägt es, der Titel ruft es ab.

**Ein JSON-Beutel, keine Felderliste.** `Vorlage.felder` ist das `toJson()`
des Modells **minus** `_nurEinmalig` (Kennung, Zeiten, Stand, gestoppte
Zeiten, Herkunft, Outlook-/ICS-Kennungen). Damit trägt eine Vorlage alles,
was man einstellen kann, auch das, was es heute noch nicht gibt: ein neues
Einstell-Feld am Modell ist ohne Zutun dabei. Der Preis steht in
`_nurEinmalig`: ein neues Feld, das **nicht** in eine Vorlage gehört, muss
dort eingetragen werden.

**Der Titel steht nur in `name`.** `_gesiebt` wirft `title` aus den Feldern,
`aufTermin`/`aufTodo` setzen ihn aus `name`. Stünde er an beiden Stellen,
setzte eine umbenannte Vorlage weiter den alten Titel.

**Die Dauer ist eine Einstellung, Start und Ende sind es nicht.**
`dauerMinuten` gibt es nur beim Termin (ein To-do hat `estimatedMinutes`).
`aufTermin` lässt den gewählten Beginn stehen und rückt nur das Ende: wer den
Termin auf 14 Uhr gelegt hat und dann „Dienst Spät" wählt, will 14–22 Uhr.
`aufTodo` lässt `scheduledDate`/`-Hour`/`-Minute` und `createdAt` stehen.

**Die Suche verzeiht (`vorlagen/vorlagensuche.dart`).** `bewertung` gibt
Stufen, klein ist besser: 0 genau, 1 Anfang, 2 Wortanfang, 3 enthalten,
`4+d` Tippfehler am Anfang, `7+d` Tippfehler in einem späteren Wort, `null`
passt nicht. Die Nachsicht wächst mit der Eingabe (`nachsicht`: ein Fehler je
vier Zeichen, höchstens drei) — unter vier Zeichen wird nichts verziehen,
sonst passt bei „Di" die halbe Liste. `abstand` ist Damerau-Levenshtein: zwei
vertauschte Nachbarn sind **ein** Fehler, weil genau das beim Tippen
passiert. `schlicht` macht ä→ae, ö→oe, ü→ue, ß→ss und wirft alles weg, was
kein Buchstabe und keine Zahl ist. Reine Rechnung — keine Datenbank, keine
Uhr, kein Bildschirm.

**Wo es im Bildschirm hängt.** `widgets/vorlagen_feld.dart` ist das Titelfeld
(ein `RawAutocomplete`, das den `_titleCtrl` des Bildschirms weiterbenutzt).
Gewählt wird über `gewaehlt:`; der Bildschirm füllt sein Formular dann aus
`v.aufTermin(_bauen())` bzw. `v.aufTodo(_bauen())`. `_bauen()` gibt das
Modell, wie es gerade im Formular steht — **ohne** zu speichern; `_save()`
benutzt dasselbe `_bauen()`, damit beide nie auseinanderlaufen. Angelegt
werden Vorlagen unten im Termin- bzw. To-do-Bildschirm („Als Vorlage
speichern"), verwaltet in den Einstellungen (`vorlagen/vorlagen_screen.dart`:
umbenennen, löschen).

**Gleicher Name derselben Art ersetzt.** Wer „Dienst Spät" zum zweiten Mal
speichert, bessert nach; Kennung und Benutzt-Zähler bleiben. Zwei
gleichnamige Vorschläge wären im Dropdown nicht zu unterscheiden — darum gibt
`umbenennen` `false`, wenn der Name schon belegt ist.

Tests: `test/vorlagen_test.dart` (Modell und Speicher),
`test/vorlagensuche_test.dart` (die Suche),
`test/vorlagen_feld_test.dart` (das Dropdown).

## Der Sog am Rand (`week/randzug.dart`)

Ein Zug endete am Bildschirmrand: wer um 9 Uhr anfasst und auf 18 Uhr will,
musste loslassen, scrollen und neu anfassen — und beim Loslassen liegt das
To-do schon irgendwo. Hält man es jetzt an die obere oder untere Kante,
läuft die Ansicht dorthin weiter.

Drei Dinge daran sind nicht beliebig:

- **Das Tempo steht in Stunden je Sekunde**, nicht in Pixeln (0,5 am inneren
  Rand der Zone bis 4,0 ganz außen). Dieselbe Pixelzahl heißt bei 60 px je
  Stunde einen halben Tag und bei 720 px ein paar Minuten; der Lauf muss sich
  nach der Zeitachse richten. Jenseits der Kante bleibt es beim schnellsten
  Lauf — der Finger darf die Ansicht verlassen.
- **Der Horcher sitzt über dem ganzen Scaffold**, nicht um den Zeitbereich.
  Zeigerereignisse gehen nach dem Aufsetzen immer denselben Weg wie beim
  ersten Druck; säße er enger, bekäme ein Zug aus der Todo-Leiste nie einen
  Sog. Und er nimmt den **Finger**, nicht `details.offset` aus dem
  DragTarget: das meint die obere Kante des Gezogenen und steht bei feinem
  Raster hunderte Pixel darüber.
- **Nach jedem Stück Lauf wird die Vorschau nachgezogen**
  (`SnapState.nachziehen()` → `nachzugNotifier` → `_rasterGeaendert`). Der
  Finger steht still, aber unter ihm ist eine andere Uhrzeit; ohne das
  verspräche der Platzhalter die alte und abgelegt würde die neue.

`SnapState.zugLaeuft` ist dafür eine **eigene** Flagge: `isDraggingNotifier`
geht erst an, wenn der Finger einen Moment ruht (sie steuert Blase und
Zoom-Leiter), und so lange darf der Sog nicht warten.

## Woran der Zoom sich festhaelt (`week/zoomanker.dart`)

Rastet die Leiter während eines Zuges feiner, dehnt sich der Tag unter dem
Finger auseinander. Eine Stelle auf dem Glas muss ihre Uhrzeit behalten —
alle anderen wandern.

Früher war das die **Mitte des Sichtfeldes**. Richtig, solange niemand etwas
hält. Während eines Zuges falsch: das Gezogene rutscht unter dem Finger weg,
und je weiter es von der Mitte entfernt war, desto weiter — der Zoom
vergrößert die Stunde davor statt der, auf die man zielt.

Jetzt hält sich der Zoom am **Finger** fest (`Zoomanker.anker`, der Punkt
kommt aus `Randzug.zeigerPunkt`). Das Gezogene bleibt liegen, wo es liegt,
und das Raster wächst darum herum. Ohne laufenden Zug bleibt es bei der
Mitte.

`Zoomanker.neueStelle` ist die Umrechnung: `((stelle + anker) * faktor -
anker)`, am Ende auf den Scrollbereich begrenzt. Der Anker wird **vor** dem
`setState` abgegriffen — danach steht die Geometrie schon auf der neuen
Stundenhöhe. Ein Finger außerhalb des Feldes (beim Sog am Rand der Normalfall)
wird auf die Kante geholt, sonst katapultiert der Sprung die Ansicht weg.

## Nur im Termin (`week/terminbindung.dart`)

Manches lässt sich nur **während** eines Termins tun: die Abrechnung im
Dienst, der Anruf im Büro. Ein To-do trägt dafür zwei Bedingungen, beide
freiwillig, beide verengend:

| Feld | Heißt |
|---|---|
| `requiredCategory` | nur Termine dieser Kategorie |
| `requiredCalendarId` | nur Termine aus diesem Kalender |

Die Kalender-Id ist die eines Abos oder `TravelService.ownCalendarId`
(`'app'`) — **dieselbe Id, unter der ein Kalender seine An-/Abfahrtszeiten
hat**, also `TravelService.calendarIdOf(event)`. Kein zweites Id-System.

Gilt nur in den Planungsmodi `categoryEvent` und `opportunistic`
(`Terminbindung.giltFuer`). Wer den Modus wegstellt, verliert beide
Bedingungen — sonst stünde am To-do eine Bedingung, die niemand mehr sieht.

`Terminbindung` ist reine Rechnung: kein Bildschirm, keine Datenbank, keine
Uhr. `week_screen._findNextValidSlot` fragt nur noch `gastgeber(...)`.

**Der Sonderfall, der die Regel erklärt:** importierte Termine tragen **alle**
die Kategorie `work` (`_parseIcs` setzt sie hart). Ein To-do „im Termin,
Kategorie Arbeit" würde damit auch im Dienstplan eines anderen Menschen
landen. Darum beherbergt ein Termin **nur zur Kenntnis** nur dann, wenn der
Kalender ausdrücklich gewählt ist — „das mache ich, während sie arbeitet" ist
eine zulässige Ansage, ein Versehen über die Kategorie nicht. Dafür bekommt
`_timedEventsOnDay` das Flag `mitNurInfo`; für freie Zeit bleibt es bei
`false`.

Ein To-do auf einen Termin **ziehen** setzt beides
(`week_screen._onTodoDroppedOnEvent`): Kategorie **und** Kalender des
Termins. Vorher zählte danach jeder gleich kategorisierte Termin aus jedem
Kalender.

Wird ein Abo **entfernt**, löst `LocalService.loeseKalenderBindung(id)` die
Bindung und die Einstellungen sagen, wie viele To-dos betroffen waren — sonst
hängt ein To-do an einer Id, die es nicht mehr gibt, und findet nie wieder
einen Platz. Ein **ausgeblendetes** Abo liefert ebenfalls keine Termine; der
To-do-Bildschirm schreibt das unter die Auswahl, statt es die Planung
ausbaden zu lassen.

### Den ersten Platz bekommt die App selbst

Ein gebundenes To-do (`Terminbindung.brauchtErstenPlatz`) bleibt **nicht** in
der Leiste unten liegen: `week_screen._planeGebundeneOhneZeit` legt es in den
nächsten passenden Termin, einmal je Planungsdurchgang. Alles andere bleibt
liegen — wann ein gewöhnliches To-do drankommt, entscheidet der Mensch.

Findet die Suche in 30 Tagen keinen Termin, merkt sich `_noSlotTodos` das
To-do, sonst liefe dieselbe 30-Tage-Suche jede Minute und die Meldung käme im
Takt wieder.

### Das To-do folgt seinem Termin

Ein gebundenes To-do gehört in **den Termin**, nicht an die Stelle, an der
der Termin mal lag. Verschiebt man den Dienst — von Hand oder weil das
Abonnement einen neuen Plan liefert —, blieb es früher dort stehen und
wartete darauf, überfällig zu werden; auf einem Tag ohne Termin hing es dann
an der Jetzt-Linie und wanderte Minute für Minute mit.

`week_screen._folgeDemTermin` prüft darum je Durchgang:
`Terminbindung.stehtIn(todo, …)` — liegt der Block noch ganz in einem
Termin, der ihn beherbergen darf? Wenn nicht, sucht `_findNextValidSlot`
**ab jetzt** den nächsten. Angesehen werden alle offenen To-dos mit Uhrzeit
ab heute (`LocalService.getOpenTodosMitZeitAb`), nicht nur die von heute: der
Dienst, der sich verschiebt, kann nächste Woche sein.

Drei Dinge, die dabei leicht schiefgehen:

- Der Block zählt **An- und Abfahrt mit**, genau wie die Platzsuche. Sonst
  gälte ein To-do als zuhause, dessen Anfahrt längst vor dem Termin beginnt.
- Der Aufrufer reicht auch die Termine des **Vortags** herein. Eine
  Nachtschicht steht im Vorrat unter ihrem Anfangstag; ohne das wäre ein
  To-do um 2 Uhr morgens heimatlos und spränge weg.
- Nicht angefasst wird, was läuft oder pausiert, und was **fest** ist. „Fest"
  ist damit der Weg, ein gebundenes To-do absichtlich außerhalb eines Termins
  stehen zu lassen — sonst holt der nächste Durchgang es zurück.

### Der Planungsvorrat (`week/planungsvorrat.dart`)

`_events`/`_icsEvents` halten nur, was die Ansicht **zeigt** — eine Woche,
im Monatsraster einen Monat. Die Platzsuche geht aber 30 Tage voraus und sah
dahinter nur leere Tage: der Dienst nächsten Montag galt als nicht vorhanden
(„kein Platz"), und „nur frei" hätte ein To-do mitten in einen Termin gelegt,
von dem sie nichts wusste.

Darum holt `_holeVorrat()` die Termine aus der **Datenbank**
(`LocalService.getAllEvents`) und aus dem **Abo-Puffer**
(`IcsService.gepufferteEvents`, 15 Minuten) — einmal je Durchgang, und nur
wenn wirklich etwas zu planen ist (`_vorrat` ist sonst `null` und wird nie
gebaut). Die Planung läuft jede Minute; ohne Puffer wäre das ein Netzabruf je
Minute.

`Planungsvorrat` selbst ist reine Rechnung: nach Tagen sortiert, Ganztägiges
getrennt, `amTag(mitNurInfo:)` für die Gastgebersuche.

**Abgehakt wird trotzdem überall.** Die Bindung steuert, wohin die App das
To-do *plant*, nicht was man selbst darf: Haken und Ziehen von Hand bleiben
frei.

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

## Liegengebliebenes nachholen (`week/nachholen.dart`)

Was gestern offen blieb, holt `_carryOverOpenTodos` auf heute — **auf jetzt**,
nicht auf die alte Uhrzeit. Dass etwas gestern um neun dran war, sagt nichts
darüber, was heute um neun los ist.

- **Jetzt-Kante**: `Nachholen.fruehestens(jetzt)` = jetzt **plus**
  `vorlauf` (5 Min.), nach hinten auf 23:59 begrenzt. Nicht davor: ein Block,
  der schon angefangen hat, hängt hinter der Jetzt-Linie und sieht aus wie
  etwas Verpasstes. Gerechnet wird mit dem **ganzen** Block — auch die
  Anfahrt liegt damit in der Zukunft, sonst wäre man schon zu spät los.
  Der Auto-Shift benutzt dieselbe Kante, das To-do steht also immer 0–5
  Minuten **vor** der Jetzt-Linie und springt alle fünf Minuten nach
- **Nacheinander**: `Nachholen.plan()` reiht die liegengebliebenen To-dos ab
  der Kante auf, mit dem ganzen Block (Anfahrt + Dauer + Heimweg), und gibt
  die Uhrzeit des To-dos selbst zurück
- **Um die Termine herum**: `Nachholen.belegteZeiten()` nimmt nur die
  **echten** Termine. Was nur zur Kenntnis dasteht, belegt nichts — darüber
  darf ein To-do liegen; Ganztägiges auch nicht, sonst wäre der Tag weg.
  Der Schalter dafür steht je abonniertem Kalender in den Einstellungen und
  je Termin im Termin-Dialog („Nur zur Info")
- **Eine Rechnung für beide**: Nachholen und Auto-Shift benutzen dieselbe
  Belegung und dieselbe Kante. Täten sie das nicht, schöbe jeder Durchgang
  die To-dos aufs Neue hin und her
- `_belegteZeitenHeute()` merkt sich den letzten Stand von heute. `_events`
  und `_icsEvents` halten nur den **sichtbaren** Zeitraum — blättert man eine
  Woche weiter, wären die heutigen Termine weg und der Shift legte das
  nächste To-do mitten in den Dienst

Tests: `test/nachholen_test.dart` (rein gerechnet, ohne Bildschirm und ohne
Datenbank), `test/carry_over_test.dart` (welche To-dos überhaupt eingesammelt
werden).

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

**Und erst einmal muss überhaupt jemand abnehmen.** Das Plugin stellt den
Wecker über AlarmManager mit einem PendingIntent auf
`ScheduledNotificationReceiver` — eine Klasse, die das Plugin mitbringt, die
aber **die App** im Manifest anmelden muss (steht so im README des Plugins).
Sie fehlte. Damit ist seit jeher keine einzige *geplante* Meldung erschienen:
keine Serien-Erinnerung, kein Ortsvorschlag. Aufgefallen ist es nicht, weil
der Test-Knopf `show()` benutzt — sofort, ohne Wecker, also ohne Empfänger.
Dazu `ScheduledNotificationBootReceiver`, der die Wecker nach einem Neustart
neu stellt; `MY_PACKAGE_REPLACED` steht mit im Filter, weil die App sich
selbst aktualisiert und das für AlarmManager dasselbe Vergessen ist.

`test/manifest_test.dart` bewacht beides. Ein fehlender Eintrag im Manifest
wirft keinen Fehler — es passiert einfach nichts, und das sieht man erst
Wochen später an der Meldung, die nie kam.

Darum stellt der Knopf *Test-Benachrichtigung* jetzt **zwei**: eine sofort
(`show()` — sagt nur, dass die App melden darf) und eine geplante 15 Sekunden
später über `DepartureReminderService.probeStellen()`, in der eingestellten
Stufe und über deren echten Kanal. Kommt die erste und die zweite nicht,
liegt es nicht am Recht, sondern am Wecker. Die Probe trägt eine Kennung aus
`'__probe__'`, die keiner echten Meldung in die Quere kommt.

### Wecker-Diagnose (`DepartureReminderService.diagnose` / `bericht`)

„Der Wecker geht nicht" heißt **vier verschiedene Dinge**, und von außen sehen
sie gleich aus:

1. Es war nichts geplant — kein Termin der nächsten 7 Tage hat eine
   Anfahrtszeit. Ohne Anfahrt gibt es nichts loszufahren, das ist die
   häufigste und harmloseste Ursache.
2. Es wurde nichts gestellt — `zonedSchedule` ist fehlgeschlagen.
3. Der Wecker steht, aber der Kanal ist in den Android-Einstellungen leise
   oder blockiert; die Meldung wird gezeigt und ist doch nicht da.
4. Der Wecker steht nur **ungefähr** (`inexactAllowWhileIdle`) — Android legt
   ungenaue Wecker zusammen und darf sie um viele Minuten verschieben. Eine
   Probe „in 15 Sekunden" kommt dann erst viel später und sieht wie ein
   Ausfall aus.

`diagnose()` **stellt zuerst wirklich eine Probe** (`probeVersuch`, fängt den
Fehler und schreibt ihn ins Protokoll) und sieht dann nach, ob sie angekommen
ist. Der Weg selbst ist die Frage; alles drumherum war schon in Ordnung, als
nichts kam. Danach fragt es für jeden der vier Punkte **Android selbst** und
gibt einen `Weckerbefund` zurück; `bericht(befund, now:)` macht daraus Text — rein
gerechnet, ohne Plugin und ohne Datenbank, darum zeilenweise testbar und
geeignet für den Fehlerbericht. In den Einstellungen hängt der Knopf
*Wecker-Diagnose* daran (mit *Kopieren*).

Die drei Fragen stehen in `ReminderService` und **werfen nie** — eine Diagnose,
die selbst abstürzt, hilft niemandem, und auf anderen Plattformen gibt es die
Antworten gar nicht:

| Frage | Antwort | Was ein `null`/leer heißt |
|-------|---------|---------------------------|
| `darfMelden()` | `bool?` | `null` = Android hat nicht geantwortet, **nicht** „nein" |
| `geplanteKennungen()` | `Set<int>?` | leer = es steht kein einziger Wecker; `null` = **nicht feststellbar** |
| `kanal(id)` | `Kanalbefund?` | `null` = Kanal gibt es nicht, in der Stufe hat es noch nie geklingelt |

Der Unterschied zwischen `null` und leer ist bei `geplanteKennungen()` kein
Feinschliff: das Plugin liest die Liste aus **derselben Ablage**, in die es
beim Stellen schreibt. Ist die kaputt, ist beides kaputt — und wer daraus „es
steht kein Wecker" macht, schickt den Leser zur Planung statt zur Ursache. Der
Bericht schreibt deshalb „nicht feststellbar" und behauptet bei keiner Zeile
„KEIN Wecker"; sie heißt dann `unklar`.

Kanäle entstehen erst, wenn die erste Meldung darin **gezeigt** wird — „noch
nicht angelegt" ist deshalb eine Aussage über die Vergangenheit, kein Fehler.
`getNotificationChannels()` des Plugins stolpert außerdem über jede
Wichtigkeit, die es nicht kennt (`firstWhere` ohne `orElse`); darum liegt die
Abfrage in `try`.

`_stellen()` gibt jetzt eine `Weckweise` zurück (`genau`, `ungenau`,
`garnicht`) und merkt die letzte in `ReminderService.zuletztGestellt`. Damit
sagt der Test-Knopf, **wie** gestellt wurde, statt es zu verschweigen — der
Rückfall auf ungenau stand vorher nur im Protokoll.

**`tz.local` ist eine Falle, nicht die naheliegende Lösung.** Es ist ein
`late`-Feld *ohne Vorgabe*: wer es anfasst, bevor `tz.initializeTimeZones()`
gelaufen ist, bekommt einen `LateInitializationError` — und das passiert beim
**Rechnen des Zeitpunkts**, noch vor jedem Kontakt mit Android. Damit fällt
jede geplante Meldung aus, während `show()` weiter funktioniert; genau dieses
Bild sucht man dann und findet es nicht. Darum rechnet
`ReminderService.zeitpunkt()` immer in `tz.UTC`.

Das ändert nichts am Ergebnis: `TZDateTime.from` behält den **Zeitpunkt** und
wechselt nur die Darstellung (`_toNative(other).toUtc()`), und das Plugin
rechnet auf Android aus Wanduhr plus Zonenname wieder denselben Moment. Die
App ruft nirgends `setLocalLocation()`, `tz.local` war also ohnehin UTC — es
steht jetzt nur da, statt es bloß zu sein.

`_einmalPlanen()` gibt jeder einzelnen Meldung ihr eigenes `try`. Vorher nahm
die erste, die Android ablehnte, alle übrigen mit: der Durchgang brach ab, die
Liste der gestellten Wecker wurde nicht einmal geschrieben, und ein einziger
kaputter Termin ließ den ganzen Wecker verstummen. Vermerkt wird nur, was
wirklich steht (`weise != garnicht`) — sonst gilt beim nächsten Durchgang als
„schon gestellt", was nie stand, und bekommt nie wieder einen Versuch.

## Imports week_screen.dart
```dart
import 'package:flutter/gestures.dart';   // PointerScrollEvent
import 'package:flutter/services.dart';   // HardwareKeyboard
import '../models/ics_source.dart';
import '../todos/todo_edit_screen.dart';
```

## R8 im Release-Build (`android/app/proguard-rules.pro`)

**Das war die Ursache, nach der wir vier Runden gesucht haben.** Jede
*geplante* Meldung fiel im fertigen APK aus — Serien-Erinnerungen,
Orts-Vorschläge, der Wecker zum Losfahren. Im Debug lief alles.

Flutter schaltet die Verkleinerung für **jeden** Release-Build selbst ein
(`FlutterPlugin.kt`: `releaseBuildType.isMinifyEnabled = true`); im Workflow
steht dazu keine Zeile, und in `build.gradle.kts` auch nicht. R8 wirft dabei
die generischen Signaturen weg. `flutter_local_notifications` legt seine
geplanten Meldungen mit Gson ab und braucht sie:

```
PlatformException(error, TypeToken must be created with a type argument:
new TypeToken<ArrayList<NotificationDetails>>() {}; When using code shrinkers
(ProGuard, R8, ...) make sure that generic signatures are preserved.)
  at ...FlutterLocalNotificationsPlugin.loadScheduledNotifications
  → saveScheduledNotification → zonedScheduleNotification → zonedSchedule
```

Drei Dinge daran sind gemein:

- `show()` kommt ohne Gson aus und funktionierte weiter. Die Test-Meldung kam
  also an, die 15 Sekunden später nicht — das sieht wie ein Rechte- oder
  Weckerzeiten-Problem aus und ist keines.
- Dasselbe Gson liest die Liste zurück. „Wecker insgesamt gestellt: 0" war
  keine Antwort, sondern derselbe Absturz noch einmal.
- „Kanal noch nicht angelegt" war Folge, nicht Ursache: Kanäle entstehen erst
  beim ersten **gezeigten** Hinweis.

Die Datei `android/app/proguard-rules.pro` behebt es; **Flutter hängt sie von
allein an die Release-Regeln, sobald es sie gibt** — eine Zeile in
`build.gradle.kts` braucht es nicht. Entscheidend sind `-keepattributes
Signature` und das Behalten von `TypeToken` samt seinen anonymen Unterklassen.

Merke für alles Künftige: R8 läuft **nur** im Release. Ein Fehler dieser Art
taucht in keinem Test, keinem `flutter run` und keinem Emulator-Debug auf,
sondern erst im APK aus dem Workflow. Wer eine Bibliothek einbaut, die zur
Laufzeit über Typen nachdenkt (Gson, Reflection, `fromJson` über Generics),
trägt ihre Regeln dort ein. `test/release_build_test.dart` hält die
wichtigsten Zeilen fest, damit sie niemand still wieder löscht.

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
