import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../services/category_service.dart';
import '../widgets/category_picker.dart';
import '../models/calendar_event.dart';
import '../services/local_service.dart';
import '../services/travel_service.dart';
import '../models/travel_times.dart';
import '../widgets/feedback_button.dart';
import '../widgets/save_feedback.dart';
import '../widgets/travel_time_picker.dart';

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
  late String _category;
  late bool _isFixed;
  late RepeatType _repeatType;
  // null = die Vorgabe des Kalenders gilt. 0 ist etwas anderes: ausdruecklich
  // keine Zeit, auch wenn der Kalender eine vorgibt.
  late int? _travelBefore;
  late int? _travelAfter;
  late TravelTimes _inherited;
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
    _category = e?.category ?? CategoryService.fallbackKey;
    _isFixed = e?.isFixed ?? false;
    _repeatType = e?.repeatType ?? RepeatType.none;
    _travelBefore = e?.travelBeforeOverride;
    _travelAfter = e?.travelAfterOverride;
    // Was ohne eigene Angabe gelten wuerde — fuer die Beschriftung der
    // Vorgabe-Schaltflaeche. Ein neuer Termin landet im eigenen Kalender.
    _inherited = e != null
        ? TravelService.inheritedFor(e)
        : TravelService.calendarTimes(TravelService.ownCalendarId);
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
        travelBeforeOverride: _travelBefore,
        travelAfterOverride: _travelAfter,
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
        travelBeforeOverride: _travelBefore,
        travelAfterOverride: _travelAfter,
      );
    }
    // Speichert in die lokale Datenbank, aus der die Ansichten lesen.
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
          TravelTimePicker(
            label: 'Anfahrt',
            minutes: _travelBefore,
            inherited: _inherited.before,
            onChanged: (v) => setState(() => _travelBefore = v),
          ),
          const SizedBox(height: 8),
          TravelTimePicker(
            label: 'Abfahrt',
            minutes: _travelAfter,
            inherited: _inherited.after,
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
          CategoryPicker(
            selected: _category,
            onChanged: (c) => setState(
                () => _category = c ?? CategoryService.fallbackKey),
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
