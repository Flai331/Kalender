# F5: Jahresplanung (Urlaubsplaner)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Manage annually recurring events (vacations, trips, traditions). A template defines the recurring event. Each year has its own `AnnualOccurrence` with optional start/end dates and notes. The planner screen shows a list grouped by year; entries without a date get a "⚠️ Datum fehlt" badge.

**Architecture:** New `AnnualEvent` model stored in a new Supabase table `annual_events`. New `YearlyPlannerScreen` (list view, current year first). `AnnualEventEditScreen` for creating/editing templates and adding year occurrences. New nav tab in `main.dart`.

**Tech Stack:** Flutter, Supabase (existing), Dart

---

## Files

- Create: `lib/models/annual_event.dart`
- Create: `lib/yearly/yearly_planner_screen.dart`
- Create: `lib/yearly/annual_event_edit_screen.dart`
- Modify: `lib/services/supabase_service.dart` — stream + save + delete for annual_events
- Modify: `lib/main.dart` — new nav tab
- Supabase dashboard: create `annual_events` table

---

## Data Model

### AnnualOccurrence
```
year: int
startDate: DateTime?   // nullable = not yet planned
endDate: DateTime?     // nullable = single-day or open-ended
notes: String
```

### AnnualEvent
```
id: String (UUID)
name: String
category: String       // reuse existing categories
colorHex: int?         // optional custom color
occurrences: List<AnnualOccurrence>
```

### Supabase table: annual_events
| column | type |
|--------|------|
| id | uuid PK |
| user_id | uuid FK |
| data | jsonb |

---

## Task 1: AnnualEvent model

**Files:**
- Create: `lib/models/annual_event.dart`

- [ ] **Step 1: Create model file**

```dart
class AnnualOccurrence {
  final int year;
  final DateTime? startDate;
  final DateTime? endDate;
  final String notes;

  AnnualOccurrence({
    required this.year,
    this.startDate,
    this.endDate,
    this.notes = '',
  });

  bool get hasDate => startDate != null;

  AnnualOccurrence copyWith({
    int? year,
    Object? startDate = _unset,
    Object? endDate = _unset,
    String? notes,
  }) {
    return AnnualOccurrence(
      year: year ?? this.year,
      startDate: startDate == _unset ? this.startDate : startDate as DateTime?,
      endDate: endDate == _unset ? this.endDate : endDate as DateTime?,
      notes: notes ?? this.notes,
    );
  }

  static const _unset = Object();

  Map<String, dynamic> toJson() => {
        'year': year,
        'startDate': startDate?.toUtc().toIso8601String(),
        'endDate': endDate?.toUtc().toIso8601String(),
        'notes': notes,
      };

  factory AnnualOccurrence.fromJson(Map<String, dynamic> json) =>
      AnnualOccurrence(
        year: json['year'] as int,
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String).toLocal()
            : null,
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String).toLocal()
            : null,
        notes: json['notes'] as String? ?? '',
      );
}

class AnnualEvent {
  final String id;
  final String name;
  final String category;
  final int? colorHex;
  final List<AnnualOccurrence> occurrences;

  AnnualEvent({
    required this.id,
    required this.name,
    this.category = 'personal',
    this.colorHex,
    this.occurrences = const [],
  });

  AnnualOccurrence? occurrenceForYear(int year) {
    final matches = occurrences.where((o) => o.year == year);
    return matches.isEmpty ? null : matches.first;
  }

  AnnualEvent copyWith({
    String? id,
    String? name,
    String? category,
    Object? colorHex = _unset,
    List<AnnualOccurrence>? occurrences,
  }) {
    return AnnualEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      colorHex: colorHex == _unset ? this.colorHex : colorHex as int?,
      occurrences: occurrences ?? this.occurrences,
    );
  }

  static const _unset = Object();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'colorHex': colorHex,
        'occurrences': occurrences.map((o) => o.toJson()).toList(),
      };

  factory AnnualEvent.fromJson(Map<String, dynamic> json) => AnnualEvent(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? 'personal',
        colorHex: json['colorHex'] as int?,
        occurrences: (json['occurrences'] as List<dynamic>?)
                ?.map((e) =>
                    AnnualOccurrence.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
```

- [ ] **Step 2: Run analyzer**

```
flutter analyze lib/models/annual_event.dart
```
Expected: no issues.

- [ ] **Step 3: Commit**

```
git add lib/models/annual_event.dart
git commit -m "feat: add AnnualEvent and AnnualOccurrence models"
```

---

## Task 2: Supabase service methods + table

**Files:**
- Modify: `lib/services/supabase_service.dart`

- [ ] **Step 1: Create Supabase table**

In Supabase dashboard, run:
```sql
create table annual_events (
  id uuid primary key,
  user_id uuid not null references auth.users(id),
  data jsonb not null
);
alter table annual_events enable row level security;
create policy "Users see own" on annual_events for all using (auth.uid() = user_id);
```

- [ ] **Step 2: Add service methods**

```dart
// ── AnnualEvents ────────────────────────────────────────────────────────────

static Stream<List<AnnualEvent>> annualEvents() {
  return _db
      .from('annual_events')
      .stream(primaryKey: ['id'])
      .eq('user_id', _uid)
      .map((rows) => rows
          .map((r) => AnnualEvent.fromJson(r['data'] as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name)));
}

static Future<void> saveAnnualEvent(AnnualEvent event) async {
  await _db.from('annual_events').upsert({
    'id': event.id,
    'user_id': _uid,
    'data': event.toJson(),
  });
}

static Future<void> deleteAnnualEvent(String id) async {
  await _db.from('annual_events').delete().eq('id', id).eq('user_id', _uid);
}
```

- [ ] **Step 3: Run analyzer**

```
flutter analyze lib/services/supabase_service.dart
```
Expected: no issues.

- [ ] **Step 4: Commit**

```
git add lib/services/supabase_service.dart
git commit -m "feat: add annualEvents stream and save/delete methods to SupabaseService"
```

---

## Task 3: YearlyPlannerScreen

**Files:**
- Create: `lib/yearly/yearly_planner_screen.dart`

- [ ] **Step 1: Create screen**

```dart
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/annual_event.dart';
import '../services/supabase_service.dart';
import 'annual_event_edit_screen.dart';

class YearlyPlannerScreen extends StatelessWidget {
  const YearlyPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = [currentYear, currentYear + 1, currentYear - 1];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Jahresplanung',
            style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AnnualEventEditScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<AnnualEvent>>(
        stream: SupabaseService.annualEvents(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data!;
          if (events.isEmpty) {
            return const Center(
              child: Text('Noch keine Jahres-Events.\nTippe + um eines hinzuzufügen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: years.length,
            itemBuilder: (context, yi) {
              final year = years[yi];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('$year',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ),
                  ...events.map((e) {
                    final occ = e.occurrenceForYear(year);
                    final hasDate = occ?.hasDate ?? false;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: e.colorHex != null
                              ? Color(e.colorHex!)
                              : AppColors.forCategory(e.category),
                        ),
                      ),
                      title: Text(e.name,
                          style: const TextStyle(color: AppColors.textPrimary)),
                      subtitle: hasDate
                          ? Text(
                              _formatDates(occ!),
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            )
                          : const Text('⚠️ Datum noch nicht geplant',
                              style: TextStyle(
                                  color: Colors.orangeAccent, fontSize: 12)),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AnnualEventEditScreen(
                                event: e, initialYear: year)),
                      ),
                    );
                  }),
                  const Divider(color: AppColors.divider),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _formatDates(AnnualOccurrence occ) {
    final df = (DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    if (occ.endDate != null) {
      return '${df(occ.startDate!)} – ${df(occ.endDate!)}';
    }
    return df(occ.startDate!);
  }
}
```

- [ ] **Step 2: Run analyzer**

```
flutter analyze lib/yearly/yearly_planner_screen.dart
```
Expected: no issues (AnnualEventEditScreen will be a forward reference — add stub first if needed).

- [ ] **Step 3: Commit**

```
git add lib/yearly/yearly_planner_screen.dart
git commit -m "feat: add YearlyPlannerScreen"
```

---

## Task 4: AnnualEventEditScreen

**Files:**
- Create: `lib/yearly/annual_event_edit_screen.dart`

- [ ] **Step 1: Create edit screen**

```dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/annual_event.dart';
import '../services/supabase_service.dart';

const _uuid = Uuid();

class AnnualEventEditScreen extends StatefulWidget {
  final AnnualEvent? event;
  final int? initialYear;

  const AnnualEventEditScreen({super.key, this.event, this.initialYear});

  @override
  State<AnnualEventEditScreen> createState() => _AnnualEventEditScreenState();
}

class _AnnualEventEditScreenState extends State<AnnualEventEditScreen> {
  late TextEditingController _nameCtrl;
  late String _category;
  late List<AnnualOccurrence> _occurrences;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _category = e?.category ?? 'personal';
    _occurrences = List.from(e?.occurrences ?? []);

    // Pre-add current year if creating new
    final year = widget.initialYear ?? DateTime.now().year;
    if (_occurrences.every((o) => o.year != year)) {
      _occurrences.add(AnnualOccurrence(year: year));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _saving) return;
    _saving = true;
    final event = AnnualEvent(
      id: widget.event?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      category: _category,
      colorHex: widget.event?.colorHex,
      occurrences: _occurrences,
    );
    await SupabaseService.saveAnnualEvent(event);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.event == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Event löschen?',
            style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await SupabaseService.deleteAnnualEvent(widget.event!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickDate(int occIndex, {required bool isStart}) async {
    final occ = _occurrences[occIndex];
    final initial = (isStart ? occ.startDate : occ.endDate) ??
        DateTime(occ.year, 6, 1);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(occ.year, 1, 1),
      lastDate: DateTime(occ.year, 12, 31),
    );
    if (date == null || !mounted) return;
    setState(() {
      _occurrences[occIndex] = isStart
          ? occ.copyWith(startDate: date)
          : occ.copyWith(endDate: date);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(widget.event == null ? 'Neues Jahres-Event' : 'Event bearbeiten',
            style: const TextStyle(color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.event != null)
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
          const SizedBox(height: 24),
          const Text('Jahres-Einträge',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          ..._occurrences.asMap().entries.map((entry) {
            final i = entry.key;
            final occ = entry.value;
            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${occ.year}',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: AppColors.textSecondary),
                          onPressed: () =>
                              setState(() => _occurrences.removeAt(i)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _pickDate(i, isStart: true),
                          child: Text(
                            occ.startDate != null
                                ? _fmt(occ.startDate!)
                                : 'Von',
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ),
                        const Text(' – ',
                            style: TextStyle(color: AppColors.textSecondary)),
                        TextButton(
                          onPressed: occ.startDate != null
                              ? () => _pickDate(i, isStart: false)
                              : null,
                          child: Text(
                            occ.endDate != null ? _fmt(occ.endDate!) : 'Bis',
                            style: TextStyle(
                                color: occ.startDate != null
                                    ? AppColors.primary
                                    : AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          TextButton.icon(
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: const Text('Jahr hinzufügen',
                style: TextStyle(color: AppColors.primary)),
            onPressed: () {
              final lastYear = _occurrences.isEmpty
                  ? DateTime.now().year
                  : _occurrences.map((o) => o.year).reduce((a, b) => a > b ? a : b);
              setState(() => _occurrences.add(AnnualOccurrence(year: lastYear + 1)));
            },
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
```

- [ ] **Step 2: Run analyzer**

```
flutter analyze lib/yearly/annual_event_edit_screen.dart
```
Expected: no issues.

- [ ] **Step 3: Commit**

```
git add lib/yearly/annual_event_edit_screen.dart
git commit -m "feat: add AnnualEventEditScreen"
```

---

## Task 5: Nav tab in main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add Jahresplanung tab**

Find the `BottomNavigationBar` (or equivalent nav) in `main.dart`. Add:
```dart
BottomNavigationBarItem(
  icon: Icon(Icons.event_repeat),
  label: 'Jahresplan',
),
```

Add corresponding screen in the body switch:
```dart
// Check how many tabs exist in main.dart — add as the last entry
// e.g. if current tabs are 0=Woche, 1=Todos, 2=Notizen, 3=Settings → new index is 4
case 4:
  return const YearlyPlannerScreen();
```

Add import:
```dart
import 'yearly/yearly_planner_screen.dart';
```

- [ ] **Step 2: Run analyzer**

```
flutter analyze lib/main.dart
```
Expected: no issues.

- [ ] **Step 3: Commit**

```
git add lib/main.dart
git commit -m "feat: add Jahresplanung tab to main navigation"
```
