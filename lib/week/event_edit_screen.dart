import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/calendar_event.dart';
import '../services/supabase_service.dart';

const _uuid = Uuid();

class EventEditScreen extends StatefulWidget {
  final CalendarEvent? event;

  const EventEditScreen({super.key, this.event});

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late DateTime _startTime;
  late DateTime _endTime;
  late EventCategory _category;
  late bool _isFixed;
  late RepeatType _repeatType;

  bool get _isNew => widget.event == null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _startTime = e?.startTime ?? _roundToNext30();
    _endTime = e?.endTime ?? _startTime.add(const Duration(hours: 1));
    _category = e?.category ?? EventCategory.personal;
    _isFixed = e?.isFixed ?? false;
    _repeatType = e?.repeatType ?? RepeatType.none;
  }

  DateTime _roundToNext30() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour,
        now.minute < 30 ? 30 : 0)
        .add(Duration(minutes: now.minute >= 30 ? 60 : 0));
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => _darkDatePicker(ctx, child),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => _darkTimePicker(ctx, child),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startTime = dt;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      } else {
        _endTime = dt;
      }
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final event = CalendarEvent(
      id: widget.event?.id ?? _uuid.v4(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      startTime: _startTime,
      endTime: _endTime,
      category: _category,
      isFixed: _isFixed,
      repeatType: _repeatType,
      source: 'app',
    );
    await SupabaseService.saveEvent(event);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(_isNew ? 'Neuer Termin' : 'Termin bearbeiten',
            style: const TextStyle(color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
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
          _Field(
            controller: _titleCtrl,
            label: 'Titel',
            hint: 'Termintitel...',
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _descCtrl,
            label: 'Beschreibung',
            hint: 'Optional...',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _SectionLabel('Zeitraum'),
          _TimeRow(
            label: 'Start',
            time: _startTime,
            onTap: () => _pickDateTime(isStart: true),
          ),
          _TimeRow(
            label: 'Ende',
            time: _endTime,
            onTap: () => _pickDateTime(isStart: false),
          ),
          const SizedBox(height: 16),
          _SectionLabel('Kategorie'),
          _CategorySelector(
            selected: _category,
            onChanged: (c) => setState(() => _category = c),
          ),
          const SizedBox(height: 16),
          _SectionLabel('Wiederholung'),
          _RepeatSelector(
            selected: _repeatType,
            onChanged: (r) => setState(() => _repeatType = r),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _isFixed,
            onChanged: (v) => setState(() => _isFixed = v),
            title: const Text('Fester Termin (nicht verschiebbar)',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: const Text(
                'Beim automatischen Zeitplan-Shift wird dieser Termin ignoriert',
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

  Widget _darkDatePicker(BuildContext ctx, Widget? child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      );

  Widget _darkTimePicker(BuildContext ctx, Widget? child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      );

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }
}

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
  Widget build(BuildContext context) {
    return TextField(
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
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final DateTime time;
  final VoidCallback onTap;

  const _TimeRow(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label,
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      trailing: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}.${time.year}  '
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  final EventCategory selected;
  final ValueChanged<EventCategory> onChanged;

  const _CategorySelector(
      {required this.selected, required this.onChanged});

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
        final color = AppColors.forCategory(c.name);
        final isSelected = selected == c;
        return ChoiceChip(
          label: Text(_labels[c] ?? c.name),
          selected: isSelected,
          onSelected: (_) => onChanged(c),
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

  const _RepeatSelector(
      {required this.selected, required this.onChanged});

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
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: 1),
        );
      }).toList(),
    );
  }
}
