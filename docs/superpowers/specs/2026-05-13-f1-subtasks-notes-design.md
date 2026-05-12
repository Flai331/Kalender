# F1: SubTask + Notizen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add interactive sub-task checklist and rename description to notes in todos.

**Architecture:** New `SubTask` class stored as JSON array inside existing `data` column. No schema migration needed. Three touch points: model, edit screen, status dialog. Todo card gets completion badge.

**Tech Stack:** Flutter, Supabase (existing), Dart

---

## Files

- Modify: `lib/models/todo.dart` — add `SubTask` class + `subTasks` field
- Modify: `lib/todos/todo_edit_screen.dart` — `_SubTaskEditor` widget, label rename
- Modify: `lib/todos/todo_status_dialog.dart` — checkbox list
- Modify: `lib/todos/todo_card.dart` — completion badge

---

## Task 1: SubTask model

**Files:**
- Modify: `lib/models/todo.dart`

- [ ] **Step 1: Add SubTask class above Todo class**

```dart
class SubTask {
  final String id;
  final String title;
  final bool isDone;

  SubTask({required this.id, required this.title, this.isDone = false});

  SubTask copyWith({String? id, String? title, bool? isDone}) =>
      SubTask(id: id ?? this.id, title: title ?? this.title, isDone: isDone ?? this.isDone);

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'isDone': isDone};

  factory SubTask.fromJson(Map<String, dynamic> json) => SubTask(
        id: json['id'] as String,
        title: json['title'] as String,
        isDone: json['isDone'] as bool? ?? false,
      );
}
```

- [ ] **Step 2: Add field to Todo**

In `Todo` class, add after `daylightMode`:
```dart
final List<SubTask> subTasks;
```

In constructor, add:
```dart
this.subTasks = const [],
```

- [ ] **Step 3: Extend copyWith**

Add parameter:
```dart
List<SubTask>? subTasks,
```
Add to return:
```dart
subTasks: subTasks ?? this.subTasks,
```

- [ ] **Step 4: Extend toJson**

Add:
```dart
'subTasks': subTasks.map((s) => s.toJson()).toList(),
```

- [ ] **Step 5: Extend fromJson**

Add:
```dart
subTasks: (json['subTasks'] as List<dynamic>?)
    ?.map((e) => SubTask.fromJson(e as Map<String, dynamic>))
    .toList() ?? [],
```

- [ ] **Step 6: Run analyzer**

```
flutter analyze lib/models/todo.dart
```
Expected: no issues.

- [ ] **Step 7: Commit**

```
git add lib/models/todo.dart
git commit -m "feat: add SubTask model and subTasks field to Todo"
```

---

## Task 2: Edit screen — SubTaskEditor + label rename

**Files:**
- Modify: `lib/todos/todo_edit_screen.dart`

- [ ] **Step 1: Add state field**

In `_TodoEditScreenState`, add:
```dart
late List<SubTask> _subTasks;
```

In `initState`, add:
```dart
_subTasks = List.from(t?.subTasks ?? []);
```

- [ ] **Step 2: Update _save() to include subTasks**

In `_save()`, add to `Todo(...)` constructor:
```dart
subTasks: _subTasks,
```

- [ ] **Step 3: Rename label and expand lines**

Change:
```dart
_Field(controller: _descCtrl, label: 'Beschreibung', hint: 'Optional...', maxLines: 3),
```
To:
```dart
_Field(controller: _descCtrl, label: 'Notizen', hint: 'Freitext, Telefonnummer, Links...', maxLines: 6),
```

- [ ] **Step 4: Add SubTaskEditor widget below notes field**

After the notes `_Field` + `SizedBox(height: 12)`, add:
```dart
_SectionLabel('Checkliste'),
_SubTaskEditor(
  subTasks: _subTasks,
  onChanged: (updated) => setState(() => _subTasks = updated),
),
const SizedBox(height: 12),
```

- [ ] **Step 5: Add _SubTaskEditor StatefulWidget at bottom of file**

```dart
class _SubTaskEditor extends StatefulWidget {
  final List<SubTask> subTasks;
  final ValueChanged<List<SubTask>> onChanged;

  const _SubTaskEditor({required this.subTasks, required this.onChanged});

  @override
  State<_SubTaskEditor> createState() => _SubTaskEditorState();
}

class _SubTaskEditorState extends State<_SubTaskEditor> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final updated = [
      ...widget.subTasks,
      SubTask(id: const Uuid().v4(), title: text),
    ];
    widget.onChanged(updated);
    _ctrl.clear();
  }

  void _remove(String id) {
    widget.onChanged(widget.subTasks.where((s) => s.id != id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.subTasks.map((s) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                s.isDone ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: AppColors.textSecondary,
              ),
              title: Text(s.title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    decoration: s.isDone ? TextDecoration.lineThrough : null,
                  )),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                onPressed: () => _remove(s.id),
              ),
            )),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Punkt hinzufügen...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.primary),
              onPressed: _add,
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Run analyzer**

```
flutter analyze lib/todos/todo_edit_screen.dart
```
Expected: no issues.

- [ ] **Step 7: Commit**

```
git add lib/todos/todo_edit_screen.dart
git commit -m "feat: add SubTaskEditor and rename description to Notizen"
```

---

## Task 3: Status dialog — interactive checkboxes

**Files:**
- Modify: `lib/todos/todo_status_dialog.dart`

- [ ] **Step 1: Read current file**

Check the existing structure of `TodoStatusDialog` (it is a `StatelessWidget`).

- [ ] **Step 2: Convert to StatefulWidget if needed**

If `TodoStatusDialog` is `StatelessWidget`, convert to `StatefulWidget` to hold local subTask state for instant UI feedback while async save completes.

- [ ] **Step 3: Add subTask section to build()**

After time info and before action buttons, add:
```dart
if (todo.subTasks.isNotEmpty) ...[
  const Divider(color: AppColors.divider),
  ...todo.subTasks.map((s) => CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: s.isDone,
        activeColor: AppColors.primary,
        title: Text(s.title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              decoration: s.isDone ? TextDecoration.lineThrough : null,
            )),
        onChanged: (val) => _toggleSubTask(s.id, val ?? false),
      )),
],
```

- [ ] **Step 4: Add _toggleSubTask method**

```dart
void _toggleSubTask(String id, bool isDone) {
  final updated = widget.todo.copyWith(
    subTasks: widget.todo.subTasks
        .map((s) => s.id == id ? s.copyWith(isDone: isDone) : s)
        .toList(),
  );
  setState(() {}); // optimistic UI via parent rebuild not possible; store locally
  SupabaseService.saveTodo(updated);
}
```

Note: Because `TodoStatusDialog` receives `Todo` as immutable parameter, store updated subTasks in local state `List<SubTask> _subTasks` initialized from `widget.todo.subTasks`. Render from `_subTasks`, update `_subTasks` on toggle.

- [ ] **Step 5: Run analyzer**

```
flutter analyze lib/todos/todo_status_dialog.dart
```
Expected: no issues.

- [ ] **Step 6: Commit**

```
git add lib/todos/todo_status_dialog.dart
git commit -m "feat: show interactive sub-task checkboxes in todo status dialog"
```

---

## Task 4: Todo card — completion badge

**Files:**
- Modify: `lib/todos/todo_card.dart`

- [ ] **Step 1: Read current TodoCard build method**

Find where title/subtitle is rendered.

- [ ] **Step 2: Add badge**

After title widget, add:
```dart
if (todo.subTasks.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      '${todo.subTasks.where((s) => s.isDone).length}/${todo.subTasks.length} ✓',
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.textSecondary,
      ),
    ),
  ),
```

- [ ] **Step 3: Run analyzer**

```
flutter analyze lib/todos/todo_card.dart
```
Expected: no issues.

- [ ] **Step 4: Commit**

```
git add lib/todos/todo_card.dart
git commit -m "feat: show sub-task completion badge on todo card"
```
