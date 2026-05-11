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
