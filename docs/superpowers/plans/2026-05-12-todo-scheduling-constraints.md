# Todo Scheduling Constraints – Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Todos bekommen Planungseinschränkungen (Kontext, Zeitfenster, Wochentage, Ganztags-Events, Gelegenheiten) und der Auto-Shift respektiert diese inkl. standortbasiertem Tageslicht.

**Architecture:** Neues `TodoContextMode`-Enum + Felder im `Todo`-Modell kodieren alle Regeln. `DaylightService` berechnet Sonnenauf/-untergang aus GPS oder Fallback-Zeitfenster. `_findNextValidSlot` in `week_screen.dart` sucht vorwärts über Tage. Opportunity-Todos hängen sich weich an Events – beim nächsten Start.

**Tech Stack:** Flutter/Dart, Supabase, `geolocator` (neu), bestehende Auto-Shift-Logik

---

## Neue Packages

```yaml
# pubspec.yaml hinzufügen:
geolocator: ^13.0.0        # GPS für Tageslicht
```

Kein Sunrise-Package nötig – Algorithmus wird inline implementiert (~30 Zeilen, genau bis ±1 Min).

---

## Dateiübersicht

| Datei | Aktion | Verantwortlichkeit |
|-------|--------|-------------------|
| `lib/models/todo.dart` | Ändern | `contextMode`, `requiredCategory`, `allowedWeekdays`, `daylightMode`, Felder + JSON |
| `lib/services/daylight_service.dart` | Neu | GPS-Standort cachen, Sonnenauf/-untergang berechnen, Fallback-Fenster |
| `lib/todos/todo_edit_screen.dart` | Ändern | Constraint-UI: Kontext-Picker, Wochentag-Chips, Tageslicht-Schalter |
| `lib/week/week_screen.dart` | Ändern | `_findNextValidSlot`, `_dayBlockedByAllDay`, `_autoShiftOverdueTodos` erweitern |
| `lib/week/week_day_column.dart` | Ändern | Ganztags-Banner, Drop-Target in Event-Blocks (Opportunity D3) |
| `lib/week/event_block.dart` | Ändern | Highlight bei Todo-Drag-Over (Opportunity D3) |
| `lib/settings/settings_screen.dart` | Ändern | Blockierende Ganztags-Kategorien, Tageslicht-Fallback-Zeiten |
| `windows/runner/` | Keine Änderung | geolocator läuft auf Windows ohne Zusatz-Setup |

---

## Phase 1 – TodoConstraint-Modell (Basis für alles)

### Task 1.1: Package hinzufügen

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: geolocator hinzufügen**

```yaml
# pubspec.yaml, unter dependencies:
  geolocator: ^13.0.0
```

- [ ] **Step 2: Dependencies holen**

```
flutter pub get
```

Expected: Keine Fehler, `pubspec.lock` aktualisiert.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add geolocator for daylight calculation"
```

---

### Task 1.2: TodoContextMode + Felder ins Modell

**Files:**
- Modify: `lib/models/todo.dart`

- [ ] **Step 1: Enum + neue Felder definieren**

Direkt vor `class Todo {` in `lib/models/todo.dart`:

```dart
enum TodoContextMode {
  anyTime,        // überall planbar (Standard)
  freeTime,       // nur in freien Slots (kein Event überlappend)
  categoryEvent,  // nur während Events einer bestimmten Kategorie
  opportunistic,  // weich an nächstes passendes Event hängen
}

enum DaylightMode {
  none,       // kein Tageslicht-Filter
  gps,        // Sonnenauf/-untergang per GPS
  manual,     // manuelles Zeitfenster (dueWindowStartHour/EndHour)
}
```

- [ ] **Step 2: Neue Felder in `class Todo` hinzufügen**

Nach `dueWindowEndHour`:

```dart
  final TodoContextMode contextMode;
  final EventCategory? requiredCategory;  // für categoryEvent + opportunistic
  final List<int>? allowedWeekdays;       // null = alle; [1..5] = Mo-Fr; 1=Mo,7=So
  final DaylightMode daylightMode;
```

Hinweis: `EventCategory` kommt aus `calendar_event.dart` – Import bereits vorhanden (`import 'calendar_event.dart';`).

- [ ] **Step 3: Konstruktor erweitern**

```dart
  Todo({
    // ... bestehende Parameter ...
    this.contextMode = TodoContextMode.anyTime,
    this.requiredCategory,
    this.allowedWeekdays,
    this.daylightMode = DaylightMode.none,
  });
```

- [ ] **Step 4: copyWith erweitern**

Parameter hinzufügen (nach `dueWindowEndHour`):

```dart
    TodoContextMode? contextMode,
    Object? requiredCategory = _unset,
    Object? allowedWeekdays = _unset,
    DaylightMode? daylightMode,
```

Return-Block:

```dart
      contextMode: contextMode ?? this.contextMode,
      requiredCategory: requiredCategory == _unset ? this.requiredCategory : requiredCategory as EventCategory?,
      allowedWeekdays: allowedWeekdays == _unset ? this.allowedWeekdays : allowedWeekdays as List<int>?,
      daylightMode: daylightMode ?? this.daylightMode,
```

- [ ] **Step 5: toJson erweitern**

```dart
        'contextMode': contextMode.name,
        'requiredCategory': requiredCategory?.name,
        'allowedWeekdays': allowedWeekdays,
        'daylightMode': daylightMode.name,
```

- [ ] **Step 6: fromJson erweitern**

```dart
        contextMode: TodoContextMode.values.firstWhere(
          (e) => e.name == json['contextMode'],
          orElse: () => TodoContextMode.anyTime,
        ),
        requiredCategory: json['requiredCategory'] != null
            ? EventCategory.values.firstWhere(
                (e) => e.name == json['requiredCategory'],
                orElse: () => EventCategory.personal,
              )
            : null,
        allowedWeekdays: (json['allowedWeekdays'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList(),
        daylightMode: DaylightMode.values.firstWhere(
          (e) => e.name == json['daylightMode'],
          orElse: () => DaylightMode.none,
        ),
```

- [ ] **Step 7: `flutter analyze` – 0 Fehler**

- [ ] **Step 8: Commit**

```bash
git add lib/models/todo.dart
git commit -m "feat: add TodoContextMode, DaylightMode, allowedWeekdays to Todo model"
```

---

### Task 1.3: DaylightService

**Files:**
- Create: `lib/services/daylight_service.dart`

- [ ] **Step 1: Service erstellen**

```dart
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DaylightService {
  static double? _cachedLat;
  static double? _cachedLng;
  static DateTime? _cacheTime;

  // Manuelle Fallback-Zeiten aus Settings
  static int fallbackSunriseHour = 6;
  static int fallbackSunsetHour = 20;

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    fallbackSunriseHour = prefs.getInt('daylight_sunrise') ?? 6;
    fallbackSunsetHour = prefs.getInt('daylight_sunset') ?? 20;
  }

  static Future<void> saveSettings(int sunrise, int sunset) async {
    fallbackSunriseHour = sunrise;
    fallbackSunsetHour = sunset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daylight_sunrise', sunrise);
    await prefs.setInt('daylight_sunset', sunset);
  }

  /// Gibt (sunriseMinutes, sunsetMinutes) seit Mitternacht zurück.
  /// Benutzt GPS wenn verfügbar, sonst Fallback.
  static Future<(int, int)> getDaylightWindow(DateTime day) async {
    final pos = await _getPosition();
    if (pos == null) {
      return (fallbackSunriseHour * 60, fallbackSunsetHour * 60);
    }
    return _calculate(pos.latitude, pos.longitude, day);
  }

  /// Sync-Version mit gecachtem Standort (für Shift-Loop).
  /// Muss nach `prefetchLocation()` aufgerufen werden.
  static (int, int) getDaylightWindowSync(DateTime day) {
    if (_cachedLat == null) {
      return (fallbackSunriseHour * 60, fallbackSunsetHour * 60);
    }
    return _calculate(_cachedLat!, _cachedLng!, day);
  }

  static Future<void> prefetchLocation() async {
    final pos = await _getPosition();
    if (pos != null) {
      _cachedLat = pos.latitude;
      _cachedLng = pos.longitude;
      _cacheTime = DateTime.now();
    }
  }

  static Future<Position?> _getPosition() async {
    // Cache 1 Stunde
    if (_cachedLat != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inHours < 1) {
      return null; // nutzt gecachte Werte
    }
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied || req == LocationPermission.deniedForever) {
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  /// NOAA vereinfachter Sonnenauf/-untergang-Algorithmus.
  /// Genauigkeit: ±1 Minute für gemäßigte Breiten.
  static (int, int) _calculate(double lat, double lng, DateTime date) {
    final n = date.difference(DateTime.utc(2000, 1, 1, 12)).inDays.toDouble();
    final L = (280.460 + 0.9856474 * n) % 360;
    final g = (357.528 + 0.9856003 * n) % 360 * math.pi / 180;
    final lambda = (L + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g)) * math.pi / 180;
    final eps = 23.439 * math.pi / 180;
    final sinDec = math.sin(eps) * math.sin(lambda);
    final dec = math.asin(sinDec);
    final latRad = lat * math.pi / 180;
    final cosH = (math.cos(90.833 * math.pi / 180) - math.sin(latRad) * sinDec) /
        (math.cos(latRad) * math.cos(dec));
    if (cosH < -1) return (0, 24 * 60);     // Mitternachtssonne
    if (cosH > 1)  return (12 * 60, 12 * 60); // Polarnacht
    final H = math.acos(cosH) * 180 / math.pi;
    final eqTime = (L - lambda * 180 / math.pi) / 15.0;
    final utcOffset = date.timeZoneOffset.inMinutes;
    final lonOffset = lng / 15.0 * 60;
    final noon = 720 - lonOffset - eqTime * 60 + utcOffset;
    final rise = (noon - H * 4).round().clamp(0, 24 * 60 - 1);
    final set  = (noon + H * 4).round().clamp(0, 24 * 60 - 1);
    return (rise, set);
  }
}
```

- [ ] **Step 2: `flutter analyze` – 0 Fehler**

- [ ] **Step 3: Commit**

```bash
git add lib/services/daylight_service.dart
git commit -m "feat: add DaylightService with GPS-based sunrise/sunset calculation"
```

---

### Task 1.4: Constraint-UI im TodoEditScreen

**Files:**
- Modify: `lib/todos/todo_edit_screen.dart`

- [ ] **Step 1: Import hinzufügen**

```dart
import '../models/calendar_event.dart';
import '../services/daylight_service.dart';
```

- [ ] **Step 2: State-Variablen hinzufügen**

```dart
late TodoContextMode _contextMode;
EventCategory? _requiredCategory;
late List<int> _allowedWeekdays;  // leere Liste = alle erlaubt
late DaylightMode _daylightMode;
```

- [ ] **Step 3: initState – Werte aus Todo laden**

```dart
_contextMode = widget.todo?.contextMode ?? TodoContextMode.anyTime;
_requiredCategory = widget.todo?.requiredCategory;
_allowedWeekdays = List.from(widget.todo?.allowedWeekdays ?? []);
_daylightMode = widget.todo?.daylightMode ?? DaylightMode.none;
```

- [ ] **Step 4: Kontext-Sektion im Formular**

Nach dem bestehenden Zeitfenster-Bereich (`_WindowPicker`) einfügen:

```dart
// ── Planungskontext ──────────────────────────────────────────────────
const SizedBox(height: 16),
Text('Planungskontext', style: Theme.of(context).textTheme.titleSmall),
const SizedBox(height: 8),

// Kontext-Modus
SegmentedButton<TodoContextMode>(
  segments: const [
    ButtonSegment(value: TodoContextMode.anyTime,       label: Text('Überall')),
    ButtonSegment(value: TodoContextMode.freeTime,      label: Text('Nur frei')),
    ButtonSegment(value: TodoContextMode.categoryEvent, label: Text('Im Termin')),
    ButtonSegment(value: TodoContextMode.opportunistic, label: Text('Gelegenheit')),
  ],
  selected: {_contextMode},
  onSelectionChanged: (s) => setState(() {
    _contextMode = s.first;
    if (_contextMode != TodoContextMode.categoryEvent &&
        _contextMode != TodoContextMode.opportunistic) {
      _requiredCategory = null;
    }
  }),
),

// Kategorie-Picker (nur wenn relevant)
if (_contextMode == TodoContextMode.categoryEvent ||
    _contextMode == TodoContextMode.opportunistic) ...[
  const SizedBox(height: 8),
  DropdownButtonFormField<EventCategory>(
    value: _requiredCategory,
    decoration: const InputDecoration(labelText: 'Termin-Kategorie'),
    items: EventCategory.values.map((c) => DropdownMenuItem(
      value: c,
      child: Text(_categoryLabel(c)),
    )).toList(),
    onChanged: (v) => setState(() => _requiredCategory = v),
  ),
],

// Wochentage
const SizedBox(height: 12),
Text('Erlaubte Wochentage', style: Theme.of(context).textTheme.bodySmall),
const SizedBox(height: 4),
_WeekdayPicker(
  selected: _allowedWeekdays,
  onChanged: (days) => setState(() => _allowedWeekdays = days),
),

// Tageslicht
const SizedBox(height: 12),
SwitchListTile(
  title: const Text('Nur bei Tageslicht'),
  subtitle: Text(_daylightMode == DaylightMode.gps
      ? 'Sonnenauf-/-untergang per GPS'
      : _daylightMode == DaylightMode.manual
          ? 'Manuelles Fenster (Einstellungen)'
          : 'Aus'),
  value: _daylightMode != DaylightMode.none,
  onChanged: (on) => setState(() =>
      _daylightMode = on ? DaylightMode.gps : DaylightMode.none),
),
if (_daylightMode != DaylightMode.none)
  Row(
    children: [
      const SizedBox(width: 16),
      TextButton(
        onPressed: () => setState(() => _daylightMode = DaylightMode.gps),
        child: Text('GPS', style: TextStyle(
          fontWeight: _daylightMode == DaylightMode.gps ? FontWeight.bold : FontWeight.normal,
        )),
      ),
      TextButton(
        onPressed: () => setState(() => _daylightMode = DaylightMode.manual),
        child: Text('Manuell', style: TextStyle(
          fontWeight: _daylightMode == DaylightMode.manual ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    ],
  ),
```

- [ ] **Step 5: Helper-Methoden hinzufügen**

```dart
String _categoryLabel(EventCategory c) => switch (c) {
  EventCategory.work     => 'Arbeit',
  EventCategory.sport    => 'Sport',
  EventCategory.vacation => 'Urlaub',
  EventCategory.personal => 'Persönlich',
};
```

- [ ] **Step 6: `_WeekdayPicker` Widget am Ende der Datei**

```dart
class _WeekdayPicker extends StatelessWidget {
  final List<int> selected;   // 1=Mo … 7=So; leer = alle
  final ValueChanged<List<int>> onChanged;

  const _WeekdayPicker({required this.selected, required this.onChanged});

  static const _labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isOn = selected.isEmpty || selected.contains(day);
        return FilterChip(
          label: Text(_labels[i]),
          selected: isOn,
          onSelected: (on) {
            final next = selected.isEmpty
                ? List.generate(7, (j) => j + 1)
                : List<int>.from(selected);
            if (on) {
              next.add(day);
            } else {
              next.remove(day);
            }
            // Alle ausgewählt = leere Liste (= "alle")
            onChanged(next.length == 7 ? [] : next);
          },
        );
      }),
    );
  }
}
```

- [ ] **Step 7: Beim Speichern Felder übergeben**

In `_saveTodo()` beim `todo.copyWith(...)`:

```dart
contextMode: _contextMode,
requiredCategory: _requiredCategory,
allowedWeekdays: _allowedWeekdays.isEmpty ? null : _allowedWeekdays,
daylightMode: _daylightMode,
```

- [ ] **Step 8: `flutter analyze` – 0 Fehler**

- [ ] **Step 9: App starten, Todo bearbeiten, Kontext-UI testen**

- [ ] **Step 10: Commit**

```bash
git add lib/todos/todo_edit_screen.dart
git commit -m "feat: add constraint UI (context mode, weekdays, daylight) to TodoEditScreen"
```

---

## Phase 2 – Ganztags-Events (Banner + Block)

### Task 2.1: Ganztags-Banner in WeekDayColumn

**Files:**
- Modify: `lib/week/week_day_column.dart`

- [ ] **Step 1: Banner in `WeekDayColumn.build()` einfügen**

Nach `_DayHeader` und vor `Expanded(child: grid)`:

```dart
if (widget.allDayEvents.isNotEmpty)
  _AllDayBanner(events: widget.allDayEvents),
```

Parameter hinzufügen in `WeekDayColumn`:

```dart
final List<CalendarEvent> allDayEvents;
```

Konstruktor:

```dart
required this.allDayEvents,
```

- [ ] **Step 2: `_AllDayBanner` Widget**

```dart
class _AllDayBanner extends StatelessWidget {
  final List<CalendarEvent> events;
  const _AllDayBanner({required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: AppColors.primary.withOpacity(0.08),
      child: Wrap(
        spacing: 4,
        children: events.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(e.title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        )).toList(),
      ),
    );
  }
}
```

- [ ] **Step 3: week_screen.dart – allDayEvents übergeben**

Events beim Übergeben an `WeekDayColumn` aufteilen:

```dart
// In _buildDayColumn() oder wo WeekDayColumn gebaut wird:
final allDay = dayEvents.where((e) => e.isAllDay).toList();
final timed  = dayEvents.where((e) => !e.isAllDay).toList();

WeekDayColumn(
  // ...
  events: timed,
  allDayEvents: allDay,
  // ...
)
```

- [ ] **Step 4: Commit**

```bash
git add lib/week/week_day_column.dart lib/week/week_screen.dart
git commit -m "feat: show all-day events as banner in day column"
```

---

### Task 2.2: Blockierende Ganztags-Events in Settings

**Files:**
- Modify: `lib/settings/settings_screen.dart`

- [ ] **Step 1: Setting speichern/laden**

`DaylightService.loadSettings()` bereits in Phase 1 vorhanden. Analoges Pattern für blockierende Kategorien in `SharedPreferences`:

```dart
// In SettingsScreen State:
List<String> _blockingAllDayCategories = ['vacation'];

Future<void> _loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _blockingAllDayCategories =
        prefs.getStringList('blocking_allday_cats') ?? ['vacation'];
    // Tageslicht-Fallback
    _daylightSunrise = prefs.getInt('daylight_sunrise') ?? 6;
    _daylightSunset  = prefs.getInt('daylight_sunset')  ?? 20;
  });
}

Future<void> _saveAllDaySettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('blocking_allday_cats', _blockingAllDayCategories);
}
```

- [ ] **Step 2: UI-Sektion in SettingsScreen**

```dart
// Ganztags-Events Sektion:
Text('Ganztags-Termine blockieren Auto-Shift', style: Theme.of(context).textTheme.titleSmall),
const SizedBox(height: 4),
...EventCategory.values.map((cat) {
  final name = cat.name;
  return CheckboxListTile(
    title: Text(_categoryLabel(cat)),
    value: _blockingAllDayCategories.contains(name),
    onChanged: (on) {
      setState(() {
        if (on == true) {
          _blockingAllDayCategories.add(name);
        } else {
          _blockingAllDayCategories.remove(name);
        }
      });
      _saveAllDaySettings();
    },
  );
}),
// Tageslicht-Fallback:
const SizedBox(height: 16),
Text('Tageslicht-Fallback (wenn kein GPS)', style: Theme.of(context).textTheme.titleSmall),
Row(children: [
  Expanded(child: _HourDrop(label: 'Sonnenaufgang', value: _daylightSunrise,
    onChanged: (h) { setState(() => _daylightSunrise = h!); DaylightService.saveSettings(_daylightSunrise, _daylightSunset); })),
  const SizedBox(width: 8),
  Expanded(child: _HourDrop(label: 'Sonnenuntergang', value: _daylightSunset,
    onChanged: (h) { setState(() => _daylightSunset = h!); DaylightService.saveSettings(_daylightSunrise, _daylightSunset); })),
]),
```

- [ ] **Step 3: Commit**

```bash
git add lib/settings/settings_screen.dart
git commit -m "feat: settings for blocking all-day event categories and daylight fallback"
```

---

## Phase 3 – Auto-Shift mit Constraints

### Task 3.1: `_findNextValidSlot` in week_screen.dart

**Files:**
- Modify: `lib/week/week_screen.dart`

Hinweis: Dieser Task ersetzt/erweitert die bestehende `_autoShiftOverdueTodos`-Logik. Die bestehende `_skipEvents`-Hilfsfunktion bleibt.

- [ ] **Step 1: DaylightService importieren + Settings laden**

```dart
import '../services/daylight_service.dart';
```

In `initState`:

```dart
DaylightService.loadSettings();
DaylightService.prefetchLocation(); // async, kein await nötig
```

- [ ] **Step 2: Helper – Tag durch Ganztags-Event blockiert?**

```dart
bool _dayBlockedByAllDay(DateTime day, List<CalendarEvent> allEvents) {
  final prefs = /* SharedPreferences-gecachter Wert – via statische Variable */ _blockingAllDayCats;
  return allEvents.any((e) =>
      e.isAllDay &&
      prefs.contains(e.category.name) &&
      e.startTime.year == day.year &&
      e.startTime.month == day.month &&
      e.startTime.day == day.day);
}

// State-Variable für blockierende Kategorien (geladen in initState):
List<String> _blockingAllDayCats = ['vacation'];

Future<void> _loadBlockingCats() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _blockingAllDayCats = prefs.getStringList('blocking_allday_cats') ?? ['vacation'];
  });
}
```

In `initState`: `_loadBlockingCats();`

- [ ] **Step 3: `_findNextValidSlot`**

```dart
/// Findet den nächsten gültigen Slot für ein Todo ab [from] (Minuten seit Mitternacht auf [fromDay]).
/// Gibt (DateTime day, int minuteOfDay) zurück oder null wenn keiner in 30 Tagen gefunden.
Future<(DateTime, int)?> _findNextValidSlot(
    Todo todo, DateTime fromDay, int fromMinute, List<CalendarEvent> allEvents) async {
  
  await DaylightService.prefetchLocation();
  
  DateTime day = fromDay;
  int startMinute = fromMinute;
  
  for (int attempt = 0; attempt < 30; attempt++) {
    // Wochentag check
    if (todo.allowedWeekdays != null && todo.allowedWeekdays!.isNotEmpty &&
        !todo.allowedWeekdays!.contains(day.weekday)) {
      day = day.add(const Duration(days: 1));
      startMinute = 0;
      continue;
    }
    
    // Ganztags-Block check
    if (_dayBlockedByAllDay(day, allEvents)) {
      day = day.add(const Duration(days: 1));
      startMinute = 0;
      continue;
    }
    
    // Tageslicht-Fenster
    int winStart = todo.dueWindowStartHour != null ? todo.dueWindowStartHour! * 60 : 0;
    int winEnd   = todo.dueWindowEndHour   != null ? todo.dueWindowEndHour!   * 60 : 24 * 60;
    
    if (todo.daylightMode == DaylightMode.gps || todo.daylightMode == DaylightMode.manual) {
      final (rise, set) = DaylightService.getDaylightWindowSync(day);
      winStart = math.max(winStart, rise);
      winEnd   = math.min(winEnd, set);
    }
    
    if (startMinute < winStart) startMinute = winStart;
    
    final total = todo.travelMinutesBefore + todo.estimatedMinutes + todo.travelMinutesAfter;
    
    // Kontext-Modus
    if (todo.contextMode == TodoContextMode.categoryEvent ||
        todo.contextMode == TodoContextMode.opportunistic) {
      // Slot muss innerhalb eines passenden Events liegen
      final dayStr = '${day.year}-${day.month}-${day.day}';
      final matchEvents = allEvents.where((e) =>
          !e.isAllDay &&
          e.category == todo.requiredCategory &&
          e.startTime.year == day.year &&
          e.startTime.month == day.month &&
          e.startTime.day == day.day).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      
      for (final ev in matchEvents) {
        final evStart = ev.startTime.hour * 60 + ev.startTime.minute;
        final evEnd   = ev.endTime.hour   * 60 + ev.endTime.minute;
        int pos = math.max(startMinute, math.max(winStart, evStart));
        if (pos + total <= math.min(winEnd, evEnd)) {
          return (day, pos);
        }
      }
      day = day.add(const Duration(days: 1));
      startMinute = 0;
      continue;
    }
    
    if (todo.contextMode == TodoContextMode.freeTime) {
      // Slot darf kein Event überlappen
      final dayEvents = allEvents.where((e) =>
          !e.isAllDay &&
          e.startTime.year == day.year &&
          e.startTime.month == day.month &&
          e.startTime.day == day.day).toList();
      int pos = startMinute;
      bool found = false;
      for (int tries = 0; tries < 200; tries++) {
        if (pos + total > winEnd) break;
        final blocked = dayEvents.any((e) {
          final es = e.startTime.hour * 60 + e.startTime.minute;
          final ee = e.endTime.hour   * 60 + e.endTime.minute;
          return pos < ee && pos + total > es;
        });
        if (!blocked) { found = true; break; }
        // Springe ans Ende des blockierenden Events
        final blocker = dayEvents.firstWhere((e) {
          final es = e.startTime.hour * 60 + e.startTime.minute;
          final ee = e.endTime.hour   * 60 + e.endTime.minute;
          return pos < ee && pos + total > es;
        });
        pos = blocker.endTime.hour * 60 + blocker.endTime.minute;
      }
      if (found) return (day, pos);
      day = day.add(const Duration(days: 1));
      startMinute = 0;
      continue;
    }
    
    // anyTime: bestehende Logik (dueWindow + _skipEvents)
    if (startMinute + total <= winEnd) {
      return (day, startMinute);
    }
    day = day.add(const Duration(days: 1));
    startMinute = winStart;
  }
  return null; // kein Slot in 30 Tagen
}
```

Import am Dateianfang:

```dart
import 'dart:math' as math;
```

- [ ] **Step 4: `_autoShiftOverdueTodos` erweitern**

Bestehende Logik anpassen: für Todos mit `contextMode != anyTime` → `_findNextValidSlot` nutzen statt bisherigem Skip-Mechanismus.

Nach dem bisherigen `_skipEvents(runningMin, totalBlock)`:

```dart
// Wenn Constraints vorhanden: präzisere Slot-Suche
if (todo.contextMode != TodoContextMode.anyTime ||
    todo.allowedWeekdays != null ||
    todo.daylightMode != DaylightMode.none) {
  final slot = await _findNextValidSlot(todo, runningDate, runningMin, allEvents);
  if (slot == null) {
    // WARNUNG: kein Slot in 30 Tagen
    _noSlotTodos.add(todo.id);
    continue;
  }
  final (slotDay, slotMin) = slot;
  // ... Todo auf slotDay/slotMin verschieben (analog zu bestehendem saveTodo-Aufruf)
  runningDate = slotDay;
  runningMin = slotMin + totalBlock;
  continue;
}
```

State-Variable für Warnungen:

```dart
final Set<String> _noSlotTodos = {};
```

- [ ] **Step 5: Warnung anzeigen**

In `week_screen.dart` build-Methode oder als `SnackBar` nach Shift:

```dart
if (_noSlotTodos.isNotEmpty) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_noSlotTodos.length} Todo(s) konnten nicht eingeplant werden – kein passender Slot in 30 Tagen.'),
      action: SnackBarAction(label: 'OK', onPressed: () => _noSlotTodos.clear()),
    ));
  });
}
```

- [ ] **Step 6: `flutter analyze` – 0 Fehler**

- [ ] **Step 7: Manuelle Tests**
  - Todo mit `contextMode=categoryEvent, requiredCategory=work` → wird in nächsten Arbeitstermin verschoben
  - Todo mit `allowedWeekdays=[1,2,3,4,5]` an Wochenende → wird auf Montag verschoben
  - Todo mit `daylightMode=gps` → bleibt in Tageslicht-Fenster
  - Todo ohne passenden Slot 30 Tage → SnackBar erscheint

- [ ] **Step 8: Commit**

```bash
git add lib/week/week_screen.dart lib/services/daylight_service.dart
git commit -m "feat: auto-shift respects context mode, weekdays, daylight, all-day blocks"
```

---

## Phase 4 – Opportunity-Todos (Drag-in-Event)

### Task 4.1: EventBlock Highlight bei Todo-Drag

**Files:**
- Modify: `lib/week/event_block.dart`

- [ ] **Step 1: `isDropTarget` Parameter hinzufügen**

```dart
// In EventBlock:
final bool isDropTarget;

const EventBlock({
  // ...
  this.isDropTarget = false,
});
```

Im Build des EventBlock-Containers:

```dart
decoration: BoxDecoration(
  // ...bestehende Decoration...
  border: isDropTarget
      ? Border.all(color: Colors.white, width: 2)
      : null,
  boxShadow: isDropTarget
      ? [BoxShadow(color: Colors.white.withOpacity(0.4), blurRadius: 8)]
      : null,
),
```

- [ ] **Step 2: Commit**

```bash
git add lib/week/event_block.dart
git commit -m "feat: EventBlock highlights when isDropTarget"
```

---

### Task 4.2: Drag-Todo-in-Event in WeekDayColumn

**Files:**
- Modify: `lib/week/week_day_column.dart`

- [ ] **Step 1: Callback-Parameter hinzufügen**

```dart
final Function(Todo todo, CalendarEvent event) onTodoDroppedOnEvent;
```

Konstruktor:

```dart
required this.onTodoDroppedOnEvent,
```

- [ ] **Step 2: DragTarget um jeden EventBlock wrappen**

In `_buildEventBlocks()`, statt direktem `LongPressDraggable<CalendarEvent>`:

```dart
DragTarget<Todo>(
  onWillAcceptWithDetails: (_) => true,
  onAcceptWithDetails: (details) {
    widget.onTodoDroppedOnEvent(details.data, event);
  },
  builder: (ctx, candidateTodos, _) {
    final isTarget = candidateTodos.isNotEmpty;
    return LongPressDraggable<CalendarEvent>(
      // ... bestehender Code ...
      child: EventBlock(
        event: event,
        onTap: () => widget.onEventTap(event),
        heightPerMinute: _minuteHeight,
        isDropTarget: isTarget,
      ),
    );
  },
)
```

- [ ] **Step 3: Commit**

```bash
git add lib/week/week_day_column.dart
git commit -m "feat: event blocks accept todo drops for opportunity scheduling"
```

---

### Task 4.3: Opportunity-Logik in week_screen.dart

**Files:**
- Modify: `lib/week/week_screen.dart`

- [ ] **Step 1: `onTodoDroppedOnEvent` Handler**

```dart
Future<void> _onTodoDroppedOnEvent(Todo todo, CalendarEvent event) async {
  // Ersten freien Slot im Event finden
  final evStart = event.startTime.hour * 60 + event.startTime.minute;
  final evEnd   = event.endTime.hour   * 60 + event.endTime.minute;
  final total   = todo.travelMinutesBefore + todo.estimatedMinutes + todo.travelMinutesAfter;
  
  if (evEnd - evStart < total) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Todo passt nicht in diesen Termin.'),
    ));
    return;
  }
  
  // Slot am Anfang des Events (einfach)
  final newStart = evStart + todo.travelMinutesBefore;
  final updated = todo.copyWith(
    scheduledDate: event.startTime,
    scheduledStartHour: newStart ~/ 60,
    scheduledStartMinute: newStart % 60,
    contextMode: TodoContextMode.opportunistic,
    requiredCategory: event.category,
  );
  await _saveTodo(updated);
  setState(() => _initStreams());
}
```

- [ ] **Step 2: Callback an WeekDayColumn übergeben**

```dart
WeekDayColumn(
  // ...
  onTodoDroppedOnEvent: _onTodoDroppedOnEvent,
)
```

- [ ] **Step 3: Wenn Opportunity-Todo nicht gestartet bis Event-Ende → nächstes Event**

In `_autoShiftOverdueTodos`, für `todo.contextMode == TodoContextMode.opportunistic`:

```dart
if (todo.contextMode == TodoContextMode.opportunistic &&
    todo.status == TodoStatus.pending) {
  // Prüfe ob geplantes Event vorbei ist
  final scheduledEnd = todo.scheduledEndTime;
  if (scheduledEnd != null && scheduledEnd.isBefore(now)) {
    // Suche nächstes passendes Event
    final slot = await _findNextValidSlot(
        todo, today, nowMinutes, allEvents);
    if (slot != null) {
      final (slotDay, slotMin) = slot;
      final newStart = slotMin + todo.travelMinutesBefore;
      final updated = todo.copyWith(
        scheduledDate: slotDay,
        scheduledStartHour: newStart ~/ 60,
        scheduledStartMinute: newStart % 60,
      );
      await _saveTodo(updated);
    }
  }
  continue;
}
```

- [ ] **Step 4: `flutter analyze` – 0 Fehler**

- [ ] **Step 5: Manuelle Tests**
  - Todo auf Event-Block ziehen → Todo erscheint innerhalb des Events
  - Event endet ohne Todo gestartet → nächsten Tag Auto-Shift in nächstes Event der Kategorie
  - Ganztags-Event-Banner sichtbar in Tagesspalte

- [ ] **Step 6: Commit**

```bash
git add lib/week/week_screen.dart
git commit -m "feat: opportunity todos auto-shift to next matching event if missed"
```

---

## Supabase-Schema-Ergänzung

Die neuen Felder müssen in der `todos`-Tabelle ergänzt werden:

```sql
ALTER TABLE todos
  ADD COLUMN IF NOT EXISTS context_mode   text NOT NULL DEFAULT 'anyTime',
  ADD COLUMN IF NOT EXISTS required_category text,
  ADD COLUMN IF NOT EXISTS allowed_weekdays  int[],
  ADD COLUMN IF NOT EXISTS daylight_mode  text NOT NULL DEFAULT 'none';
```

Alternativ: Felder in bestehendem JSON-Blob speichern wenn die Tabelle ein `meta jsonb`-Feld hat.

---

## Gesamtaufwand

| Phase | Aufwand |
|-------|---------|
| Phase 1 – Modell + DaylightService + UI | 4–5h |
| Phase 2 – Ganztags-Banner + Settings | 2–3h |
| Phase 3 – Auto-Shift Constraints | 4–5h |
| Phase 4 – Opportunity Drag | 3–4h |
| **Gesamt** | **13–17h** |
