# F4: Adaptive Todo-Zeiten

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repeating todos silently learn from actual completion time. After each completion, actual duration is recorded and `estimatedMinutes` updated to the rolling average (max 10 entries).

**Architecture:** `Todo` gets a `durationHistory: List<int>` field (list of actual minutes, capped at 10). When a repeating todo is marked done, the status dialog computes `actualEnd - actualStart - pausedMinutes`, appends to history, recalculates average, and saves. No user prompt. Only applies to todos with `repeatType != RepeatType.none`.

**Tech Stack:** Flutter, Supabase (existing), Dart

---

## Files

- Modify: `lib/models/todo.dart` — add `durationHistory` field
- Modify: `lib/todos/todo_status_dialog.dart` — compute + save on done action

---

## Task 1: Add durationHistory to Todo model

**Files:**
- Modify: `lib/models/todo.dart`

- [ ] **Step 1: Add field**

In `Todo` class, add after `daylightMode`:
```dart
final List<int> durationHistory; // actual minutes per completion, max 10
```

In constructor:
```dart
this.durationHistory = const [],
```

- [ ] **Step 2: Extend copyWith**

Add parameter:
```dart
List<int>? durationHistory,
```
Add to return:
```dart
durationHistory: durationHistory ?? this.durationHistory,
```

- [ ] **Step 3: Extend toJson**

Add:
```dart
'durationHistory': durationHistory,
```

- [ ] **Step 4: Extend fromJson**

Add:
```dart
durationHistory: (json['durationHistory'] as List<dynamic>?)
    ?.map((e) => (e as num).toInt())
    .toList() ?? [],
```

- [ ] **Step 5: Run analyzer**

```
flutter analyze lib/models/todo.dart
```
Expected: no issues.

- [ ] **Step 6: Commit**

```
git add lib/models/todo.dart
git commit -m "feat: add durationHistory field to Todo model"
```

---

## Task 2: Record and adapt on completion

**Files:**
- Modify: `lib/todos/todo_status_dialog.dart`

- [ ] **Step 1: Find where 'done' action is handled**

In `todo_status_dialog.dart`, the `Navigator.pop(context, 'done')` returns `'done'` to the caller (e.g. `week_screen.dart`). The adaptation logic should run in the caller after the status update, OR inside the dialog before popping.

Best location: in `week_screen.dart` (and `todo_list_screen.dart`) where `case 'done'` is handled, after setting `status = TodoStatus.done`.

- [ ] **Step 2: Add _adaptTodoTime helper in week_screen.dart**

```dart
Todo _adaptTodoTime(Todo todo) {
  if (todo.repeatType == RepeatType.none) return todo;
  if (todo.actualStart == null || todo.actualEnd == null) return todo;

  final actualMinutes = todo.actualEnd!
      .difference(todo.actualStart!)
      .inMinutes - todo.pausedMinutes;
  if (actualMinutes <= 0) return todo;

  final history = [...todo.durationHistory, actualMinutes];
  final capped = history.length > 10 ? history.sublist(history.length - 10) : history;
  final avg = (capped.reduce((a, b) => a + b) / capped.length).round();

  return todo.copyWith(
    durationHistory: capped,
    estimatedMinutes: avg,
  );
}
```

- [ ] **Step 3: Call in 'done' handler**

In `week_screen.dart` where `case 'done':` is handled:
```dart
case 'done':
  final withStatus = todo.copyWith(
    status: TodoStatus.done,
    isCompleted: true,
    actualEnd: DateTime.now(),
  );
  final adapted = _adaptTodoTime(withStatus);
  await SupabaseService.saveTodo(adapted);
```

- [ ] **Step 4: Add same helper and call in todo_list_screen.dart**

Same pattern as Step 2–3 for the todo list screen's 'done' handler.

- [ ] **Step 5: Run analyzer**

```
flutter analyze lib/week/week_screen.dart lib/todos/todo_list_screen.dart
```
Expected: no issues.

- [ ] **Step 6: Commit**

```
git add lib/week/week_screen.dart lib/todos/todo_list_screen.dart
git commit -m "feat: silently adapt estimatedMinutes from rolling average on todo completion"
```
