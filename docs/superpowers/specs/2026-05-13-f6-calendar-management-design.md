# F6: Kalender-Management

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace fixed EventCategory enum with user-created dynamic calendars. Each calendar has a name, color, 0..n ICS feeds, and an auto-shift blocking flag. Existing IcsSources and events are migrated transparently. Todos reference calendars instead of categories.

**Architecture:** New `Calendar` model stored in Supabase `calendars` table. `CalendarEvent.category` replaced by `calendarId: String`. `Todo.category` replaced by `calendarId: String?`. Existing IcsSources each become a new Calendar with one feed. One default calendar ("Persönlich") created on first launch via SharedPreferences flag. Settings screen replaces IcsSource list + blocking-category checkboxes with a calendar management section.

**Tech Stack:** Flutter, Supabase (existing), Dart

---

## Data Model

### Calendar
```
id: String (UUID)
name: String
color: int (ARGB)
icsFeeds: List<IcsSource>   // 0..n feeds, reuse existing IcsSource model
blocksAutoShift: bool        // replaces blocking_allday_cats per category
```

### IcsSource (unchanged)
Stays as inner model inside Calendar. No structural change.

### Supabase table: calendars
| column | type |
|--------|------|
| id | uuid PK |
| user_id | uuid FK auth.users(id) |
| data | jsonb |

### CalendarEvent changes
- Remove: `category: EventCategory`
- Add: `calendarId: String` (default `''` = default calendar)
- Keep: `calendarColor` field (for ICS events that carry their own color)
- Backward compat: `fromJson` maps old `category` value to `calendarId = ''`

### Todo changes
- Remove: `category: String`
- Add: `calendarId: String?` (null = no calendar filter)
- Remove: `requiredCategory: EventCategory?`
- Add: `requiredCalendarId: String?` (for `TodoContextMode.categoryEvent`)
- Backward compat: `fromJson` sets `calendarId = null` if field missing

---

## Files

- Create: `lib/models/calendar.dart`
- Create: `lib/services/calendar_service.dart` — CRUD + Supabase stream + one-time migration
- Create: `lib/calendars/calendar_list_screen.dart` — list all calendars, tap to edit
- Create: `lib/calendars/calendar_edit_screen.dart` — create/edit: name, color, feeds, blocksAutoShift
- Modify: `lib/models/calendar_event.dart` — replace category with calendarId
- Modify: `lib/models/todo.dart` — replace category/requiredCategory with calendarId/requiredCalendarId
- Modify: `lib/app_colors.dart` — add `forCalendarId(String id, List<Calendar> calendars)` helper
- Modify: `lib/settings/settings_screen.dart` — replace IcsSource + blocking-cats sections with calendar link
- Modify: `lib/week/event_edit_screen.dart` — calendar picker instead of category dropdown
- Modify: `lib/todos/todo_edit_screen.dart` — calendar picker instead of category dropdown
- Modify: `lib/week/week_screen.dart` — use calendar color/blocking instead of EventCategory
- Supabase dashboard: create `calendars` table

---

## Task 1: Calendar model

**Files:**
- Create: `lib/models/calendar.dart`

- [ ] **Step 1: Create model**

```dart
import 'ics_source.dart';

class Calendar {
  final String id;
  final String name;
  final int color; // ARGB
  final List<IcsSource> icsFeeds;
  final bool blocksAutoShift;

  const Calendar({
    required this.id,
    required this.name,
    required this.color,
    this.icsFeeds = const [],
    this.blocksAutoShift = false,
  });

  Calendar copyWith({
    String? id,
    String? name,
    int? color,
    List<IcsSource>? icsFeeds,
    bool? blocksAutoShift,
  }) => Calendar(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    icsFeeds: icsFeeds ?? this.icsFeeds,
    blocksAutoShift: blocksAutoShift ?? this.blocksAutoShift,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'icsFeeds': icsFeeds.map((f) => f.toJson()).toList(),
    'blocksAutoShift': blocksAutoShift,
  };

  factory Calendar.fromJson(Map<String, dynamic> json) => Calendar(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as int,
    icsFeeds: (json['icsFeeds'] as List<dynamic>?)
            ?.map((e) => IcsSource.fromJson(e as Map<String, dynamic>))
            .toList() ?? [],
    blocksAutoShift: json['blocksAutoShift'] as bool? ?? false,
  );
}
```

- [ ] **Step 2: Run analyzer**
```
flutter analyze lib/models/calendar.dart
```

- [ ] **Step 3: Commit**
```
git add lib/models/calendar.dart
git commit -m "feat: add Calendar model"
```

---

## Task 2: CalendarService + Supabase table

**Files:**
- Create: `lib/services/calendar_service.dart`

- [ ] **Step 1: Create Supabase table**

In Supabase SQL Editor:
```sql
create table calendars (
  id uuid primary key,
  user_id uuid not null references auth.users(id),
  data jsonb not null
);
alter table calendars enable row level security;
create policy "Users see own" on calendars for all using (auth.uid() = user_id);
```

- [ ] **Step 2: Create CalendarService**

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/calendar.dart';
import '../models/ics_source.dart';
import 'auth_service.dart';
import 'ics_service.dart';

const _uuid = Uuid();
const _defaultCalendarKey = 'default_calendar_id';
const _calendarsMigratedKey = 'calendars_migrated';

// Default color: orange (former 'personal' color)
const _defaultColor = 0xFFFF6D00;

class CalendarService {
  static final _db = Supabase.instance.client;
  static String get _uid => AuthService.userId ?? '';

  // ── Stream ────────────────────────────────────────────────────────────────

  static Stream<List<Calendar>> calendarsStream() {
    return _db
        .from('calendars')
        .stream(primaryKey: ['id'])
        .eq('user_id', _uid)
        .map((rows) => rows
            .map((r) => Calendar.fromJson(r['data'] as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)));
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  static Future<void> saveCalendar(Calendar cal) async {
    await _db.from('calendars').upsert({
      'id': cal.id,
      'user_id': _uid,
      'data': cal.toJson(),
    });
  }

  static Future<void> deleteCalendar(String id) async {
    await _db.from('calendars').delete().eq('id', id).eq('user_id', _uid);
  }

  static Future<List<Calendar>> getCalendars() async {
    final rows = await _db.from('calendars').select().eq('user_id', _uid);
    return (rows as List)
        .map((r) => Calendar.fromJson(r['data'] as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // ── Default calendar ID ───────────────────────────────────────────────────

  static Future<String> getDefaultCalendarId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultCalendarKey) ?? '';
  }

  // ── One-time migration ────────────────────────────────────────────────────

  /// Runs once on first launch after F6 update.
  /// 1. Creates default "Persönlich" calendar.
  /// 2. Migrates each existing IcsSource to its own Calendar.
  static Future<void> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_calendarsMigratedKey) == true) return;

    // 1. Create default calendar
    final defaultId = _uuid.v4();
    final defaultCal = Calendar(
      id: defaultId,
      name: 'Persönlich',
      color: _defaultColor,
      blocksAutoShift: false,
    );
    await saveCalendar(defaultCal);
    await prefs.setString(_defaultCalendarKey, defaultId);

    // 2. Migrate existing IcsSources → one Calendar each
    final sources = await IcsService.getSources();
    for (final src in sources) {
      final cal = Calendar(
        id: _uuid.v4(),
        name: src.name,
        color: src.color ?? 0xFF448AFF,
        icsFeeds: [src],
        blocksAutoShift: false,
      );
      await saveCalendar(cal);
    }

    await prefs.setBool(_calendarsMigratedKey, true);
  }
}
```

- [ ] **Step 3: Run analyzer**
```
flutter analyze lib/services/calendar_service.dart
```

- [ ] **Step 4: Commit**
```
git add lib/services/calendar_service.dart
git commit -m "feat: add CalendarService with Supabase stream, CRUD, and one-time migration"
```

---

## Task 3: Update CalendarEvent model

**Files:**
- Modify: `lib/models/calendar_event.dart`

- [ ] **Step 1: Replace category with calendarId**

Remove `EventCategory` enum and field. Add `calendarId: String`.

In field declarations, replace:
```dart
final EventCategory category;
```
with:
```dart
final String calendarId; // UUID of Calendar; '' = default calendar
```

In constructor, replace:
```dart
this.category = EventCategory.personal,
```
with:
```dart
this.calendarId = '',
```

In `copyWith`, replace `EventCategory? category` parameter with `String? calendarId` and update return accordingly.

In `toJson`, replace `'category': category.name` with `'calendarId': calendarId`.

In `fromJson`, add backward-compat mapping:
```dart
calendarId: json['calendarId'] as String? ?? '',
```
(Old events with only `category` field get `calendarId = ''` which resolves to the default calendar.)

- [ ] **Step 2: Remove EventCategory enum**

Delete the `enum EventCategory { work, sport, vacation, personal }` declaration from `calendar_event.dart`.

Check all files that import `EventCategory` and update them:
```
flutter analyze lib/
```
Fix every reference to `EventCategory` — most will be in settings and week screen.

- [ ] **Step 3: Commit**
```
git add lib/models/calendar_event.dart
git commit -m "feat: replace EventCategory with calendarId on CalendarEvent"
```

---

## Task 4: Update Todo model

**Files:**
- Modify: `lib/models/todo.dart`

- [ ] **Step 1: Replace category and requiredCategory**

Replace:
```dart
final String category;
final EventCategory? requiredCategory;
```
with:
```dart
final String? calendarId;       // null = no calendar filter
final String? requiredCalendarId; // for categoryEvent context mode
```

Update constructor defaults:
```dart
this.calendarId,
this.requiredCalendarId,
```

Update `copyWith`, `toJson`, `fromJson` accordingly.

`fromJson` backward compat:
```dart
calendarId: json['calendarId'] as String?,
requiredCalendarId: json['requiredCalendarId'] as String?,
```
(Old todos had `category: 'personal'` — `calendarId` will be null, resolved to default calendar in UI.)

Rename `TodoContextMode.categoryEvent` → keep name but its semantics now use `requiredCalendarId`.

- [ ] **Step 2: Analyze and fix**
```
flutter analyze lib/models/todo.dart
```

- [ ] **Step 3: Commit**
```
git add lib/models/todo.dart
git commit -m "feat: replace category/requiredCategory with calendarId on Todo"
```

---

## Task 5: CalendarListScreen + CalendarEditScreen

**Files:**
- Create: `lib/calendars/calendar_list_screen.dart`
- Create: `lib/calendars/calendar_edit_screen.dart`

- [ ] **Step 1: Create CalendarListScreen**

Shows StreamBuilder of CalendarService.calendarsStream(). Each item: color dot, name, feed count. Tap → CalendarEditScreen. FAB → new CalendarEditScreen.

```dart
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/calendar.dart';
import '../services/calendar_service.dart';
import 'calendar_edit_screen.dart';

class CalendarListScreen extends StatelessWidget {
  const CalendarListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Kalender', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CalendarEditScreen())),
          ),
        ],
      ),
      body: StreamBuilder<List<Calendar>>(
        stream: CalendarService.calendarsStream(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final cals = snap.data!;
          if (cals.isEmpty) {
            return const Center(
              child: Text('Keine Kalender.\nTippe + um einen zu erstellen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView.separated(
            itemCount: cals.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.divider, height: 1),
            itemBuilder: (context, i) {
              final cal = cals[i];
              return ListTile(
                leading: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(cal.color),
                  ),
                ),
                title: Text(cal.name, style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(
                  cal.icsFeeds.isEmpty
                      ? 'Manuell'
                      : '${cal.icsFeeds.length} Feed${cal.icsFeeds.length > 1 ? "s" : ""}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                trailing: cal.blocksAutoShift
                    ? const Icon(Icons.block, size: 14, color: AppColors.textDisabled)
                    : null,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CalendarEditScreen(calendar: cal))),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Create CalendarEditScreen**

Fields: name (TextField), color picker (row of 8 preset colors), blocksAutoShift (Switch), icsFeeds list with add URL / add .ics file buttons (reuse existing IcsService.addUrl / addFile logic), delete button for existing feeds.

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/calendar.dart';
import '../models/ics_source.dart';
import '../services/calendar_service.dart';
import '../services/ics_service.dart';

const _uuid = Uuid();

const _presetColors = [
  0xFFFF6D00, // orange
  0xFF448AFF, // blue
  0xFF69F0AE, // green
  0xFFFFD740, // yellow
  0xFFFF5252, // red
  0xFF6C63FF, // purple
  0xFF00BCD4, // cyan
  0xFF9E9E9E, // grey
];

class CalendarEditScreen extends StatefulWidget {
  final Calendar? calendar;
  const CalendarEditScreen({super.key, this.calendar});

  @override
  State<CalendarEditScreen> createState() => _CalendarEditScreenState();
}

class _CalendarEditScreenState extends State<CalendarEditScreen> {
  late TextEditingController _nameCtrl;
  late int _color;
  late bool _blocksAutoShift;
  late List<IcsSource> _feeds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.calendar;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _color = c?.color ?? _presetColors[0];
    _blocksAutoShift = c?.blocksAutoShift ?? false;
    _feeds = List.from(c?.icsFeeds ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _saving) return;
    _saving = true;
    final cal = Calendar(
      id: widget.calendar?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      color: _color,
      icsFeeds: _feeds,
      blocksAutoShift: _blocksAutoShift,
    );
    await CalendarService.saveCalendar(cal);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.calendar == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Kalender löschen?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Events bleiben erhalten, haben dann keinen Kalender.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await CalendarService.deleteCalendar(widget.calendar!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _addUrl() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('ICS-Feed hinzufügen',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Name',
                    labelStyle: TextStyle(color: AppColors.textSecondary))),
            const SizedBox(height: 8),
            TextField(controller: urlCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                decoration: const InputDecoration(labelText: 'webcal:// oder https://',
                    labelStyle: TextStyle(color: AppColors.textSecondary))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Hinzufügen')),
        ],
      ),
    );
    if (ok != true) return;
    final url = urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _feeds.add(IcsSource(
      id: _uuid.v4(),
      name: nameCtrl.text.trim().isEmpty ? url : nameCtrl.text.trim(),
      url: url,
    )));
  }

  Future<void> _addFile() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['ics']);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() => _feeds.add(IcsSource(
      id: _uuid.v4(),
      name: result.files.single.name.replaceAll('.ics', ''),
      url: path,
      isFile: true,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(widget.calendar == null ? 'Neuer Kalender' : 'Kalender bearbeiten',
            style: const TextStyle(color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.calendar != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _delete,
            ),
          TextButton(
            onPressed: _save,
            child: const Text('Speichern',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Farbe', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: _presetColors.map((c) {
              final selected = _color == c;
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(c),
                    border: selected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ganztags-Termine blockieren Auto-Shift',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            value: _blocksAutoShift,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _blocksAutoShift = v),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text('ICS-Feeds', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
              TextButton.icon(
                icon: const Icon(Icons.link, size: 14, color: AppColors.primary),
                label: const Text('URL', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                onPressed: _addUrl,
              ),
              TextButton.icon(
                icon: const Icon(Icons.attach_file, size: 14, color: AppColors.primary),
                label: const Text('Datei', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                onPressed: _addFile,
              ),
            ],
          ),
          ..._feeds.asMap().entries.map((e) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(e.value.isFile ? Icons.attach_file : Icons.link,
                size: 16, color: AppColors.textSecondary),
            title: Text(e.value.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            subtitle: Text(e.value.url,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.textSecondary),
              onPressed: () => setState(() => _feeds.removeAt(e.key)),
            ),
          )),
          if (_feeds.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Keine Feeds — nur manuelle Termine.',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run analyzer**
```
flutter analyze lib/calendars/
```

- [ ] **Step 4: Commit**
```
git add lib/calendars/
git commit -m "feat: add CalendarListScreen and CalendarEditScreen"
```

---

## Task 6: Update Settings screen

**Files:**
- Modify: `lib/settings/settings_screen.dart`

- [ ] **Step 1: Remove IcsSource section + blocking-cats checkboxes**

Remove:
- `_sources` / `_sourcesLoading` state
- `_loadSources()`, `_addUrl()`, `_addFile()`, `_toggleIcsAllowTodoDrop()` methods
- The IcsSources ListView section in build
- `_blockingAllDayCats` state, `_saveBlockingCats()`, the checkboxes section

- [ ] **Step 2: Add calendar link**

Replace removed sections with a single ListTile:
```dart
ListTile(
  leading: const Icon(Icons.calendar_month, color: AppColors.primary),
  title: const Text('Kalender verwalten',
      style: TextStyle(color: AppColors.textPrimary)),
  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
  onTap: () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const CalendarListScreen())),
),
```

Add import: `import '../calendars/calendar_list_screen.dart';`

- [ ] **Step 3: Run analyzer**
```
flutter analyze lib/settings/settings_screen.dart
```

- [ ] **Step 4: Commit**
```
git add lib/settings/settings_screen.dart
git commit -m "feat: replace IcsSource+blocking-cats in settings with calendar link"
```

---

## Task 7: Update event_edit_screen + todo_edit_screen

**Files:**
- Modify: `lib/week/event_edit_screen.dart`
- Modify: `lib/todos/todo_edit_screen.dart`

- [ ] **Step 1: Update EventEditScreen**

Replace category dropdown with calendar picker.

Read `lib/week/event_edit_screen.dart`. Find the `EventCategory` dropdown and replace with a `StreamBuilder<List<Calendar>>` driven `DropdownButton<String>` for `calendarId`.

State: `late String _calendarId` (initialized from `widget.event?.calendarId ?? ''`).

In `_save()`: `calendarId: _calendarId` instead of `category: _category`.

- [ ] **Step 2: Update TodoEditScreen**

Same pattern. Replace `_category` state with `_calendarId` (nullable). In `_save()`: `calendarId: _calendarId`.

- [ ] **Step 3: Run analyzer**
```
flutter analyze lib/week/event_edit_screen.dart lib/todos/todo_edit_screen.dart
```

- [ ] **Step 4: Commit**
```
git add lib/week/event_edit_screen.dart lib/todos/todo_edit_screen.dart
git commit -m "feat: replace category pickers with calendar pickers in edit screens"
```

---

## Task 8: Update week_screen + auto-shift blocking

**Files:**
- Modify: `lib/week/week_screen.dart`
- Modify: `lib/services/shift_service.dart` (if auto-shift logic lives there)

- [ ] **Step 1: Fix color resolution**

In `week_screen.dart`, every place that calls `AppColors.forCategory(event.category)` must be replaced. Add a helper in week_screen.dart:

```dart
Color _calendarColor(CalendarEvent event, List<Calendar> calendars) {
  if (event.calendarColor != null) return Color(event.calendarColor!);
  final cal = calendars.where((c) => c.id == event.calendarId).firstOrNull;
  return cal != null ? Color(cal.color) : AppColors.primary;
}
```

Pass `_calendars` list (from `CalendarService.getCalendars()` loaded once in `initState`) through to event blocks.

- [ ] **Step 2: Fix auto-shift blocking**

In auto-shift logic, the check `_blockingAllDayCats.contains(event.category.name)` becomes:

```dart
final cal = _calendars.where((c) => c.id == event.calendarId).firstOrNull;
final blocks = cal?.blocksAutoShift ?? false;
```

- [ ] **Step 3: Run analyzer**
```
flutter analyze lib/week/week_screen.dart
```

- [ ] **Step 4: Commit**
```
git add lib/week/week_screen.dart
git commit -m "feat: use calendar color and blocksAutoShift in week screen"
```

---

## Task 9: Wire migration in main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Call migration after auth**

After `await AuthService.ensureSignedIn()` succeeds, add:
```dart
await CalendarService.migrateIfNeeded();
```

Add import: `import 'services/calendar_service.dart';`

- [ ] **Step 2: Run full analyzer**
```
flutter analyze lib/
```
Fix any remaining `EventCategory` references.

- [ ] **Step 3: Commit**
```
git add lib/main.dart
git commit -m "feat: run CalendarService migration on startup"
```
