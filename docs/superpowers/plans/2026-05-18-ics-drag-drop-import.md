# ICS Drag & Drop Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users drag a `.ics` file onto the week view to import its events once into a chosen calendar.

**Architecture:** Wrap the week screen `body` Stack in a `DropRegion` (from `desktop_drop`). On drop of a `.ics` file, parse it with a new public `IcsService.parseIcsRaw()` wrapper, show a dialog with calendar picker, then write each event to the local DB via `LocalService.saveEvent()`.

**Tech Stack:** Flutter, `desktop_drop` package, existing `IcsService`, `LocalService`, `CalendarService`

---

### Task 1: Add `desktop_drop` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependency**

In `pubspec.yaml`, under `dependencies:`, add after `file_picker: ^8.1.2`:

```yaml
  desktop_drop: ^0.4.4
```

- [ ] **Step 2: Install**

```
flutter pub get
```

Expected output: resolves `desktop_drop` with no conflicts.

- [ ] **Step 3: Commit**

```
git add pubspec.yaml pubspec.lock
git commit -m "chore: add desktop_drop dependency"
```

---

### Task 2: Expose `IcsService.parseIcsRaw()`

**Files:**
- Modify: `lib/services/ics_service.dart`

- [ ] **Step 1: Add public wrapper after `fetchEvents()`**

In `lib/services/ics_service.dart`, after line 115 (end of `fetchEvents()`), add:

```dart
  static List<CalendarEvent> parseIcsRaw(String raw) =>
      _parseIcs(raw, calendarName: '');
```

- [ ] **Step 2: Verify it compiles**

```
flutter analyze lib/services/ics_service.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```
git add lib/services/ics_service.dart
git commit -m "feat: expose IcsService.parseIcsRaw() for one-time import"
```

---

### Task 3: Add `_IcsImportDialog` widget to `week_screen.dart`

**Files:**
- Modify: `lib/week/week_screen.dart`

- [ ] **Step 1: Add import at top of `week_screen.dart`**

After the existing imports (after line 26 `import '../todos/todo_edit_screen.dart';`), add:

```dart
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
```

- [ ] **Step 2: Add `_IcsImportDialog` at the bottom of `week_screen.dart`** (after the last class/widget in the file)

```dart
class _IcsImportDialog extends StatefulWidget {
  final List<CalendarEvent> events;
  final String filename;

  const _IcsImportDialog({required this.events, required this.filename});

  @override
  State<_IcsImportDialog> createState() => _IcsImportDialogState();
}

class _IcsImportDialogState extends State<_IcsImportDialog> {
  List<Calendar> _calendars = [];
  String _selectedCalendarId = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cals = await CalendarService.getCalendars();
    final defaultId = await CalendarService.getDefaultCalendarId();
    if (!mounted) return;
    setState(() {
      _calendars = cals;
      _selectedCalendarId = cals.any((c) => c.id == defaultId)
          ? defaultId
          : (cals.isNotEmpty ? cals.first.id : '');
      _loading = false;
    });
  }

  Future<void> _import() async {
    for (final event in widget.events) {
      await LocalService.saveEvent(
        event.copyWith(calendarId: _selectedCalendarId),
      );
    }
    if (mounted) Navigator.pop(context, widget.events.length);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.filename,
          style: const TextStyle(color: AppColors.textPrimary)),
      content: _loading
          ? const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.events.length} Events gefunden',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                if (_calendars.isNotEmpty)
                  DropdownButton<String>(
                    value: _selectedCalendarId.isEmpty ? null : _selectedCalendarId,
                    dropdownColor: AppColors.surface,
                    isExpanded: true,
                    items: _calendars
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCalendarId = v);
                    },
                  ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: widget.events.isEmpty || _loading ? null : _import,
          child: const Text('Importieren',
              style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Verify it compiles**

```
flutter analyze lib/week/week_screen.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```
git add lib/week/week_screen.dart
git commit -m "feat: add _IcsImportDialog widget for ICS import"
```

---

### Task 4: Add drag state + `DropRegion` to `WeekScreenState`

**Files:**
- Modify: `lib/week/week_screen.dart`

- [ ] **Step 1: Add `_isDragOver` state field to `WeekScreenState`**

In `WeekScreenState`, after `bool _isDayView = false;` (around line 40), add:

```dart
bool _isDragOver = false;
```

- [ ] **Step 2: Add `_handleDrop()` method to `WeekScreenState`**

Add this method anywhere in `WeekScreenState` (e.g. after `reload()`):

```dart
Future<void> _handleDrop(DropDoneDetails details) async {
  final file = details.files.firstWhere(
    (f) => f.name.toLowerCase().endsWith('.ics'),
    orElse: () => details.files.first,
  );
  if (!file.name.toLowerCase().endsWith('.ics')) return;

  final String raw;
  try {
    raw = await File(file.path).readAsString();
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datei konnte nicht gelesen werden')),
    );
    return;
  }

  final events = IcsService.parseIcsRaw(raw);
  if (!mounted) return;

  final count = await showDialog<int>(
    context: context,
    builder: (_) => _IcsImportDialog(
      events: events,
      filename: file.name,
    ),
  );

  if (count != null && count > 0 && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count Events importiert')),
    );
  }
}
```

- [ ] **Step 3: Wrap the `body:` Stack in a `DropRegion`**

In `build()`, the current `body:` is:

```dart
      body: Stack(
        children: [
          Column(
```

Replace with:

```dart
      body: DropRegion(
        formats: const [DropFormats.fileUri],
        onDragEntered: (_) => setState(() => _isDragOver = true),
        onDragExited: (_) => setState(() => _isDragOver = false),
        onDragDone: (details) {
          setState(() => _isDragOver = false);
          _handleDrop(details);
        },
        child: Stack(
          children: [
            Column(
```

Also close the new `DropRegion` — find the closing `),` of the outer `Stack` (the one wrapping the Column and the AnimatedBuilder overlay) and add one extra `)` to close the `DropRegion`:

The structure becomes:
```
DropRegion(
  ...
  child: Stack(        ← existing Stack
    children: [
      Column(...),
      AnimatedBuilder(...),   ← existing drag overlay
    ],
  ),                   ← closes Stack
),                     ← closes DropRegion
```

- [ ] **Step 4: Add the hover overlay inside the Stack**

Inside the same `Stack`'s `children:` list, after the `AnimatedBuilder` block, add:

```dart
          if (_isDragOver)
            Container(
              color: AppColors.primary.withOpacity(0.15),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today,
                        size: 48, color: AppColors.primary),
                    SizedBox(height: 12),
                    Text('ICS-Datei loslassen',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
```

- [ ] **Step 5: Verify it compiles**

```
flutter analyze lib/week/week_screen.dart
```

Expected: no errors.

- [ ] **Step 6: Commit**

```
git add lib/week/week_screen.dart
git commit -m "feat: ICS drag & drop import on week screen"
```

---

### Task 5: Manual smoke test

- [ ] **Step 1: Run the app**

```
flutter run -d windows
```

- [ ] **Step 2: Test golden path**

  1. Export a `.ics` file from any calendar app (or use a test file with a few VEVENTs)
  2. Drag the `.ics` file over the week screen
  3. Verify: blue overlay appears while hovering
  4. Drop the file
  5. Verify: dialog opens with correct filename, event count, and calendar dropdown
  6. Select a calendar, tap "Importieren"
  7. Verify: snackbar "N Events importiert" appears
  8. Verify: events appear immediately in the week view (stream auto-updates)

- [ ] **Step 3: Test edge cases**

  - Drop a non-`.ics` file (e.g. `.txt`) → nothing happens, no crash
  - Drop a `.ics` file with 0 valid VEVENTs → dialog shows "0 Events gefunden", "Importieren" button disabled
  - Tap "Abbrechen" → no events saved, no snackbar

- [ ] **Step 4: Commit final**

```
git add .
git commit -m "test: verify ICS drag & drop import smoke test passes"
```
