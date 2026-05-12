import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/todo.dart';
import '../models/calendar_event.dart';
import '../services/supabase_service.dart';
import '../widgets/feedback_button.dart';

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
  late TextEditingController _addressCtrl;
  late int _estimatedMinutes;
  late RepeatType _repeatType;
  late bool _isFixed;
  late String _category;
  late int _travelBefore;
  late int _travelAfter;
  int? _windowStartHour;
  int? _windowEndHour;
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
    _addressCtrl = TextEditingController(text: t?.address ?? '');
    _estimatedMinutes = t?.estimatedMinutes ?? 30;
    _repeatType = t?.repeatType ?? RepeatType.none;
    _isFixed = t?.isFixed ?? false;
    _category = t?.category ?? 'personal';
    _travelBefore = t?.travelMinutesBefore ?? 0;
    _travelAfter = t?.travelMinutesAfter ?? 0;
    _windowStartHour = t?.dueWindowStartHour;
    _windowEndHour = t?.dueWindowEndHour;
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
      isCompleted: widget.todo?.isCompleted ?? false,
      actualStart: widget.todo?.actualStart,
      actualEnd: widget.todo?.actualEnd,
      pausedMinutes: widget.todo?.pausedMinutes ?? 0,
      pauseStart: widget.todo?.pauseStart,
      outlookTaskId: widget.todo?.outlookTaskId,
      outlookListId: widget.todo?.outlookListId,
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      travelMinutesBefore: _travelBefore,
      travelMinutesAfter: _travelAfter,
      dueWindowStartHour: _windowStartHour,
      dueWindowEndHour: _windowEndHour,
      contextMode: _contextMode,
      requiredCategory: _requiredCategory,
      allowedWeekdays: _allowedWeekdays.isEmpty ? null : _allowedWeekdays,
      daylightMode: _daylightMode,
      repeatConfig: widget.todo?.repeatConfig,
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
          const FeedbackIconButton(),
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
          const SizedBox(height: 12),
          _Field(
            controller: _addressCtrl,
            label: 'Adresse',
            hint: 'Ort / Adresse (optional)...',
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          _TravelTimePicker(
            label: 'Anfahrt',
            minutes: _travelBefore,
            onChanged: (v) => setState(() => _travelBefore = v),
          ),
          const SizedBox(height: 8),
          _TravelTimePicker(
            label: 'Abfahrt',
            minutes: _travelAfter,
            onChanged: (v) => setState(() => _travelAfter = v),
          ),
          const SizedBox(height: 16),

          // Erledigungszeitraum
          _SectionLabel('Erledigungszeitraum (optional)'),
          _WindowPicker(
            startHour: _windowStartHour,
            endHour: _windowEndHour,
            onChanged: (s, e) => setState(() {
              _windowStartHour = s;
              _windowEndHour = e;
            }),
          ),
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
            activeThumbColor: AppColors.fixedTag,
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
            activeThumbColor: AppColors.primary,
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
    _addressCtrl.dispose();
    super.dispose();
  }
}

// ── Subwidgets ──────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final IconData? prefixIcon;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.prefixIcon,
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
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: AppColors.textSecondary, size: 18)
              : null,
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      );
}

class _TravelTimePicker extends StatelessWidget {
  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  const _TravelTimePicker({
    required this.label,
    required this.minutes,
    required this.onChanged,
  });

  static const _options = [0, 5, 10, 15, 20, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          label == 'Anfahrt' ? Icons.directions_car_outlined : Icons.directions_car,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _options.map((m) {
                final isSelected = minutes == m;
                final lbl = m == 0 ? 'Keine' : '${m}min';
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onChanged(m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.divider,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        lbl,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
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

class _DurationPicker extends StatefulWidget {
  final int minutes;
  final ValueChanged<int> onChanged;

  const _DurationPicker({required this.minutes, required this.onChanged});

  static const _options = [15, 30, 45, 60, 90, 120, 180, 240];

  @override
  State<_DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<_DurationPicker> {
  late TextEditingController _ctrl;

  bool get _isCustom => !_DurationPicker._options.contains(widget.minutes);

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _isCustom ? '${widget.minutes}' : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onCustomSubmit(String val) {
    final parsed = int.tryParse(val.trim());
    if (parsed != null && parsed > 0) widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _DurationPicker._options.map((m) {
            final isSelected = widget.minutes == m;
            final label = m < 60
                ? '${m}min'
                : '${m ~/ 60}h${m % 60 > 0 ? '${m % 60}m' : ''}';
            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) {
                _ctrl.clear();
                widget.onChanged(m);
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.3),
              backgroundColor: AppColors.card,
              labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 13),
              side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.divider),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 140,
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Eigene Minuten',
              hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 13),
              suffixText: 'min',
              suffixStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              filled: true,
              fillColor: _isCustom
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: _isCustom ? AppColors.primary : AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: _isCustom ? AppColors.primary : AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            onSubmitted: _onCustomSubmit,
            onChanged: (v) {
              final parsed = int.tryParse(v.trim());
              if (parsed != null && parsed > 0) widget.onChanged(parsed);
            },
          ),
        ),
      ],
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
          selectedColor: color.withValues(alpha: 0.3),
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

class _WindowPicker extends StatelessWidget {
  final int? startHour;
  final int? endHour;
  final void Function(int? start, int? end) onChanged;

  const _WindowPicker({
    required this.startHour,
    required this.endHour,
    required this.onChanged,
  });

  static const _hours = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23];

  @override
  Widget build(BuildContext context) {
    final active = startHour != null && endHour != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Nur in bestimmtem Zeitfenster verschieben',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
              Switch(
                value: active,
                onChanged: (v) => onChanged(v ? 8 : null, v ? 22 : null),
                activeThumbColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          if (active) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Von', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(width: 8),
                _HourDrop(
                  value: startHour!,
                  options: _hours.where((h) => h < (endHour ?? 24)).toList(),
                  onChanged: (v) => onChanged(v, endHour),
                ),
                const SizedBox(width: 12),
                const Text('Bis', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(width: 8),
                _HourDrop(
                  value: endHour!,
                  options: _hours.where((h) => h > (startHour ?? 0)).toList(),
                  onChanged: (v) => onChanged(startHour, v),
                ),
                const Text(' Uhr', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HourDrop extends StatelessWidget {
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  const _HourDrop({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: options.contains(value) ? value : options.first,
          items: options.map((h) => DropdownMenuItem(
            value: h,
            child: Text('$h:00',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
          dropdownColor: AppColors.surface,
          isDense: true,
          style: const TextStyle(color: AppColors.textPrimary),
          iconEnabledColor: AppColors.primary,
        ),
      ),
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
          selectedColor: AppColors.primary.withValues(alpha: 0.3),
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
          selectedColor: AppColors.primary.withValues(alpha: 0.3),
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
          selectedColor: AppColors.primary.withValues(alpha: 0.3),
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
          selectedColor: AppColors.primary.withValues(alpha: 0.3),
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
