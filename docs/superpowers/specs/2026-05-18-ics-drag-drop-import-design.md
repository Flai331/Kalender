# ICS Drag & Drop Import

**Date:** 2026-05-18  
**Status:** Approved

## Summary

User can drag a `.ics` file onto the week view. A dialog shows the number of found events and lets the user pick a target calendar. On confirmation, events are written once to the local DB.

## User Flow

1. User drags `.ics` file over the week screen
2. Week screen shows a semi-transparent blue overlay while hovering
3. On drop: file is read and parsed
4. `_IcsImportDialog` opens:
   - Title: filename (e.g. "urlaub.ics")
   - Subtitle: "23 Events gefunden"
   - Calendar dropdown (all calendars, default calendar pre-selected)
   - "Importieren" + "Abbrechen" buttons
5. On confirm: each parsed event saved via `LocalService.saveEvent()` with the chosen `calendarId`
6. Snackbar: "23 Events importiert"

## Architecture

### New dependency
- `desktop_drop` package added to `pubspec.yaml` — provides `DropRegion` widget with Windows/macOS/Linux support

### Changes to `IcsService`
- `_parseIcs()` is currently private. Add public wrapper:
  ```dart
  static List<CalendarEvent> parseIcsRaw(String raw) =>
      _parseIcs(raw, calendarName: '');
  ```

### Changes to `week_screen.dart`
- Wrap the week content in `DropRegion` from `desktop_drop`
- Handle `onDragDone`: read dropped `.ics` file, parse, show dialog
- Handle `onDragUpdated` / `onDragExited`: toggle hover overlay state
- Add `_IcsImportDialog` widget (stateful, inline in file):
  - Receives `List<CalendarEvent>` + filename
  - Loads calendars from `CalendarService.getCalendars()`
  - Pre-selects `CalendarService.getDefaultCalendarId()`
  - On confirm: loops events, sets `calendarId`, calls `LocalService.saveEvent()`

### No changes needed
- `IcsSource` model — not used (one-time import, no feed)
- DB schema — `CalendarEvent` already has `calendarId`
- `LocalService` — `saveEvent()` already exists

## Error Handling

- Non-`.ics` file dropped → silently ignore (check extension before parsing)
- Parse yields 0 events → show dialog with "0 Events gefunden", "Importieren" disabled
- File read error → Snackbar "Datei konnte nicht gelesen werden"

## Out of Scope

- Recurring events (RRULE) — parsed as single instances, same as existing ICS feed behavior
- Undo import
- Progress indicator for large files
