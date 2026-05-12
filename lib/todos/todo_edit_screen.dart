import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/todo.dart';
import '../models/calendar_event.dart';
import '../services/supabase_service.dart';

const _uuid = Uuid();

class TodoEditScreen extends StatefulWidget {
  final Todo? todo;

  const TodoEditScreen({super.key, this.todo});

  @override
  State<TodoEditScreen> createState() => _TodoEditScreenState();
}

class _TodoEditScreenState extends State<TodoEditScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late int _estimatedMinutes;
  late RepeatType _repeatType;
  late bool _isFixed;
  late String _category;
  late TodoContextMode _contextMode;
  EventCategory? _requiredCategory;
  late List<int> _allowedWeekdays;
  late DaylightMode _daylightMode;

  bool get _isNew => widget.todo == null;

  @override
  void initState() {
    super.initState();
    final t = widget.todo;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _descCtrl = TextEditingController(text: t?.description ?? '');
    _estimatedMinutes = t?.estimatedMinutes ?? 30;
    _repeatType = t?.repeatType ?? RepeatType.none;
    _isFixed = t?.isFixed ?? false;
    _category = t?.category ?? 'personal';
    _contextMode = t?.contextMode ?? TodoContextMode.anyTime;
    _requiredCategory = t?.requiredCategory;
    _allowedWeekdays = List.from(t?.allowedWeekdays ?? []);
    _daylightMode = t?.daylightMode ?? DaylightMode.none;
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final todo = Todo(
      id: widget.todo?.id ?? _uuid.v4(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      estimatedMinutes: _estimatedMinutes,
      repeatType: _repeatType,
      isFixed: _isFixed,
      category: _category,
      createdAt: widget.todo?.createdAt ?? DateTime.now(),
      scheduledDate: widget.todo?.scheduledDate,
      scheduledStartHour: widget.todo?.scheduledStartHour,
      scheduledStartMinute: widget.todo?.scheduledStartMinute,
      status: widget.todo?.status ?? TodoStatus.pending,
      // Constraint-Felder erhalten/setzen
      isCompleted: widget.todo?.isCompleted ?? false,
      actualStart: widget.todo?.actualStart,
      actualEnd: widget.todo?.actualEnd,
      pausedMinutes: widget.todo?.pausedMinutes ?? 0,
      pauseStart: widget.todo?.pauseStart,
      outlookTaskId: widget.todo?.outlookTaskId,
      outlookListId: widget.todo?.outlookListId,
      address: widget.todo?.address,
      travelMinutesBefore: widget.todo?.travelMinutesBefore ?? 0,
      travelMinutesAfter: widget.todo?.travelMinutesAfter ?? 0,
      dueWindowStartHour: widget.todo?.dueWindowStartHour,
      dueWindowEndHour: widget.todo?.dueWindowEndHour,
      contextMode: _contextMode,
      requiredCategory: _requiredCategory,
      allowedWeekdays: _allowedWeekdays.isEmpty ? null : _allowedWeekdays,
      daylightMode: _daylightMode,
    );
    await SupabaseService.saveTodo(todo);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.todo == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Todo löschen?',
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
      await SupabaseService.deleteTodo(widget.todo!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(_isNew ? 'Neues Todo' : 'Todo bearbeiten',
            style: const TextStyle(color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _delete,
            ),
          TextButton(
            onPressed: _save,
            child: const Text('Speichern',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Titel
          _Field(controller: _titleCtrl, label: 'Titel', hint: 'Was ist zu tun?'),
          const SizedBox(height: 12),
          _Field(
              controller: _descCtrl,
              label: 'Beschreibung',
              hint: 'Optional...',
              maxLines: 3),
          const SizedBox(height: 16),

          // Zeitansatz
          _SectionLabel('Zeitansatz'),
          _DurationPicker(
            minutes: _estimatedMinutes,
            onChanged: (v) => setState(() => _estimatedMinutes = v),
          ),
          const SizedBox(height: 16),

          // Kategorie
          _SectionLabel('Kategorie'),
          _CategorySelector(
            selected: _category,
            onChanged: (c) => setState(() => _category = c),
          ),
          const SizedBox(height: 16),

          // Wiederholung
          _SectionLabel('Wiederholung'),
          _RepeatSelector(
            selected: _repeatType,
            onChanged: (r) => setState(() => _repeatType = r),
          ),
          const SizedBox(height: 16),

          // Fest/Flexibel
          SwitchListTile(
            value: _isFixed,
            onChanged: (v) => setState(() => _isFixed = v),
            title: const Text('Festes Todo (nicht verschiebbar)',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: const Text(
                'Beim automatischen Zeitplan-Shift wird dieses Todo ignoriert',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            activeColor: AppColors.fixedTag,
            tileColor: AppColors.card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 16),

          // Planungskontext
          _SectionLabel('Planungskontext'),
          _ContextModePicker(
            selected: _contextMode,
            onChanged: (m) => setState(() {
              _contextMode = m;
              if (m != TodoContextMode.categoryEvent &&
                  m != TodoContextMode.opportunistic) {
                _requiredCategory = null;
              }
            }),
          ),
          if (_contextMode == TodoContextMode.categoryEvent ||
              _contextMode == TodoContextMode.opportunistic) ...[
            const SizedBox(height: 8),
            _CategoryEventPicker(
              selected: _requiredCategory,
              onChanged: (c) => setState(() => _requiredCategory = c),
            ),
          ],
          const SizedBox(height: 12),
          _SectionLabel('Erlaubte Wochentage'),
          _WeekdayPicker(
            selected: _allowedWeekdays,
            onChanged: (days) => setState(() => _allowedWeekdays = days),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _daylightMode != DaylightMode.none,
            onChanged: (on) => setState(() =>
                _daylightMode = on ? DaylightMode.gps : DaylightMode.none),
            title: const Text('Nur bei Tageslicht',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text(
              _daylightMode == DaylightMode.gps
                  ? 'GPS-basiert (Sonnenauf-/untergang)'
                  : _daylightMode == DaylightMode.manual
                      ? 'Manuelles Fenster (aus Einstellungen)'
                      : 'Aus',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            activeColor: AppColors.primary,
            tileColor: AppColors.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          if (_daylightMode != DaylightMode.none) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _daylightMode = DaylightMode.gps),
                  child: Text(
                    'GPS',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: _daylightMode == DaylightMode.gps
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _daylightMode = DaylightMode.manual),
                  child: Text(
                    'Manuell',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: _daylightMode == DaylightMode.manual
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }
}

// ── Subwidgets ──────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textDisabled),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
}

class _DurationPicker extends StatelessWidget {
  final int minutes;
  final ValueChanged<int> onChanged;

  const _DurationPicker({required this.minutes, required this.onChanged});

  static const _options = [15, 30, 45, 60, 90, 120, 180, 240];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _options.map((m) {
        final isSelected = minutes == m;
        final label = m < 60
            ? '${m}min'
            : '${m ~/ 60}h${m % 60 > 0 ? '${m % 60}m' : ''}';
        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => onChanged(m),
          selectedColor: AppColors.primary.withOpacity(0.3),
          backgroundColor: AppColors.card,
          labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontSize: 13),
          side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.divider),
        );
      }).toList(),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategorySelector(
      {required this.selected, required this.onChanged});

  static const _options = {
    'personal': 'Persönlich',
    'work': 'Arbeit',
    'sport': 'Sport',
    'vacation': 'Urlaub',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _options.entries.map((e) {
        final color = AppColors.forCategory(e.key);
        final isSelected = selected == e.key;
        return ChoiceChip(
          label: Text(e.value),
          selected: isSelected,
          onSelected: (_) => onChanged(e.key),
          selectedColor: color.withOpacity(0.3),
          backgroundColor: AppColors.card,
          labelStyle: TextStyle(
              color: isSelected ? color : AppColors.textSecondary,
              fontSize: 13),
          side: BorderSide(
              color: isSelected ? color : AppColors.divider, width: 1),
        );
      }).toList(),
    );
  }
}

class _RepeatSelector extends StatelessWidget {
  final RepeatType selected;
  final ValueChanged<RepeatType> onChanged;

  const _RepeatSelector({required this.selected, required this.onChanged});

  static const _labels = {
    RepeatType.none: 'Keine',
    RepeatType.daily: 'Täglich',
    RepeatType.weekly: 'Wöchentlich',
    RepeatType.monthly: 'Monatlich',
    RepeatType.yearly: 'Jährlich',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: RepeatType.values.map((r) {
        final isSelected = selected == r;
        return ChoiceChip(
          label: Text(_labels[r] ?? r.name),
          selected: isSelected,
          onSelected: (_) => onChanged(r),
          selectedColor: AppColors.primary.withOpacity(0.3),
          backgroundColor: AppColors.card,
          labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontSize: 13),
          side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.divider),
        );
      }).toList(),
    );
  }
}

// ── Constraint-Widgets ────────────────────────────────────────────────────────

class _ContextModePicker extends StatelessWidget {
  final TodoContextMode selected;
  final ValueChanged<TodoContextMode> onChanged;

  const _ContextModePicker({required this.selected, required this.onChanged});

  static const _labels = {
    TodoContextMode.anyTime: 'Überall',
    TodoContextMode.freeTime: 'Nur frei',
    TodoContextMode.categoryEvent: 'Im Termin',
    TodoContextMode.opportunistic: 'Gelegenheit',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: TodoContextMode.values.map((m) {
        final isSelected = selected == m;
        return ChoiceChip(
          label: Text(_labels[m] ?? m.name),
          selected: isSelected,
          onSelected: (_) => onChanged(m),
          selectedColor: AppColors.primary.withOpacity(0.3),
          backgroundColor: AppColors.card,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 13,
          ),
          side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.divider),
        );
      }).toList(),
    );
  }
}

class _CategoryEventPicker extends StatelessWidget {
  final EventCategory? selected;
  final ValueChanged<EventCategory?> onChanged;

  const _CategoryEventPicker({required this.selected, required this.onChanged});

  static const _labels = {
    EventCategory.work: 'Arbeit',
    EventCategory.sport: 'Sport',
    EventCategory.vacation: 'Urlaub',
    EventCategory.personal: 'Persönlich',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: EventCategory.values.map((c) {
        final isSelected = selected == c;
        return ChoiceChip(
          label: Text(_labels[c] ?? c.name),
          selected: isSelected,
          onSelected: (_) => onChanged(isSelected ? null : c),
          selectedColor: AppColors.primary.withOpacity(0.3),
          backgroundColor: AppColors.card,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 13,
          ),
          side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.divider),
        );
      }).toList(),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  final List<int> selected;
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
            onChanged(next.length == 7 ? [] : next);
          },
          selectedColor: AppColors.primary.withOpacity(0.3),
          backgroundColor: AppColors.card,
          labelStyle: TextStyle(
            color: isOn ? AppColors.primary : AppColors.textSecondary,
            fontSize: 13,
          ),
          side:
              BorderSide(color: isOn ? AppColors.primary : AppColors.divider),
        );
      }),
    );
  }
}
