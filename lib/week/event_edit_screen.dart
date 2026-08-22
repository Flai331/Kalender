import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/calendar_event.dart';
import '../services/local_service.dart';
import '../widgets/feedback_button.dart';
import '../widgets/save_feedback.dart';

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
  late TextEditingController _addressCtrl;
  late DateTime _startTime;
  late DateTime _endTime;
  late EventCategory _category;
  late bool _isFixed;
  late RepeatType _repeatType;
  late int _travelBefore;
  late int _travelAfter;
  bool _saving = false;

  bool get _isNew => widget.event == null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _startTime = e?.startTime ?? _roundToNext30();
    _endTime = e?.endTime ?? _startTime.add(const Duration(hours: 1));
    _category = e?.category ?? EventCategory.personal;
    _isFixed = e?.isFixed ?? false;
    _repeatType = e?.repeatType ?? RepeatType.none;
    _travelBefore = e?.travelMinutesBefore ?? 0;
    _travelAfter = e?.travelMinutesAfter ?? 0;
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
    if (_saving) return;
    if (_titleCtrl.text.trim().isEmpty) {
      showInfoSnack(context, 'Bitte einen Titel eingeben.');
      return;
    }
    setState(() => _saving = true);
    final address = _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim();
    final base = widget.event;
    final CalendarEvent event;
    if (base != null) {
      event = base.copyWith(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
        category: _category,
        isFixed: _isFixed,
        repeatType: _repeatType,
        source: 'app',
        address: address,
        travelMinutesBefore: _travelBefore,
        travelMinutesAfter: _travelAfter,
      );
    } else {
      event = CalendarEvent(
        id: _uuid.v4(),
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
        category: _category,
        isFixed: _isFixed,
        repeatType: _repeatType,
        source: 'app',
        address: address,
        travelMinutesBefore: _travelBefore,
        travelMinutesAfter: _travelAfter,
      );
    }
    // Lokal speichern + Sync-Queue (wie week_screen.dart) — funktioniert
    // auch offline, statt direkt gegen Supabase zu schreiben.
    bool ok = false;
    try {
      ok = await guardedAction(
        context,
        () => LocalService.saveEvent(event),
        errorPrefix: 'Termin speichern fehlgeschlagen',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (ok && mounted) Navigator.pop(context);
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
          const FeedbackIconButton(),
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else
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
            activeThumbColor: AppColors.fixedTag,
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
    _addressCtrl.dispose();
    super.dispose();
  }
}

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
}

class _TravelTimePicker extends StatefulWidget {
  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  const _TravelTimePicker({
    required this.label,
    required this.minutes,
    required this.onChanged,
  });

  @override
  State<_TravelTimePicker> createState() => _TravelTimePickerState();
}

class _TravelTimePickerState extends State<_TravelTimePicker> {
  static const _options = [0, 5, 10, 15, 20, 30, 45, 60];
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.minutes == 0 ? '' : '${widget.minutes}',
    );
  }

  @override
  void didUpdateWidget(_TravelTimePicker old) {
    super.didUpdateWidget(old);
    if (old.minutes != widget.minutes) {
      final txt = widget.minutes == 0 ? '' : '${widget.minutes}';
      if (_ctrl.text != txt) {
        _ctrl.text = txt;
        _ctrl.selection = TextSelection.collapsed(offset: txt.length);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          widget.label == 'Anfahrt'
              ? Icons.directions_car_outlined
              : Icons.directions_car,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(widget.label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._options.map((m) {
                  final isSelected = widget.minutes == m;
                  final lbl = m == 0 ? 'Keine' : '${m}min';
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => widget.onChanged(m),
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
                }),
                // Custom freetext input
                SizedBox(
                  width: 64,
                  height: 30,
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: !_options.contains(widget.minutes) && widget.minutes > 0
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'min',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: AppColors.textDisabled),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      filled: true,
                      fillColor: !_options.contains(widget.minutes) && widget.minutes > 0
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: !_options.contains(widget.minutes) && widget.minutes > 0
                              ? AppColors.primary
                              : AppColors.divider,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: !_options.contains(widget.minutes) && widget.minutes > 0
                              ? AppColors.primary
                              : AppColors.divider,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed >= 0) {
                        widget.onChanged(parsed);
                      } else if (val.isEmpty) {
                        widget.onChanged(0);
                      }
                    },
                  ),
                ),
              ],
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
          selectedColor: AppColors.primary.withValues(alpha: 0.3),
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
