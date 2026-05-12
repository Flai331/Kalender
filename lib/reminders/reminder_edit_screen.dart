import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/series_reminder.dart';
import '../models/yearly_checklist.dart';
import '../services/supabase_service.dart';
import '../services/outlook_service.dart';
import '../widgets/feedback_button.dart';

const _uuid = Uuid();

class ReminderEditScreen extends StatefulWidget {
  final SeriesReminder? reminder;

  const ReminderEditScreen({super.key, this.reminder});

  @override
  State<ReminderEditScreen> createState() => _ReminderEditScreenState();
}

class _ReminderEditScreenState extends State<ReminderEditScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _keywordCtrl;
  late TextEditingController _messageCtrl;
  late int _normalDay;
  late int _fallbackDay;
  late int _fallbackOffset;
  late int _windowStartHour;
  late int _windowEndHour;
  late bool _isActive;

  List<Map<String, dynamic>> _calendars = [];
  String? _selectedCalendarId;
  bool _loadingCalendars = false;

  bool get _isNew => widget.reminder == null;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _keywordCtrl =
        TextEditingController(text: r?.triggerEventKeyword ?? '');
    _messageCtrl = TextEditingController(text: r?.message ?? '');
    _normalDay = r?.normalTriggerDay ?? 7;
    _fallbackDay = r?.fallbackDay ?? 9;
    _fallbackOffset = r?.fallbackOffsetMinutes ?? 60;
    _windowStartHour = r?.windowStartHour ?? 8;
    _windowEndHour = r?.windowEndHour ?? 22;
    _isActive = r?.isActive ?? true;
    _selectedCalendarId = r?.outlookCalendarId.isNotEmpty == true
        ? r!.outlookCalendarId
        : null;
    _loadCalendars();
  }

  Future<void> _loadCalendars() async {
    setState(() => _loadingCalendars = true);
    final cals = await OutlookService.getCalendars();
    if (mounted) {
      setState(() {
        _calendars = cals;
        _loadingCalendars = false;
      });
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final reminder = SeriesReminder(
      id: widget.reminder?.id ?? _uuid.v4(),
      title: _titleCtrl.text.trim(),
      outlookCalendarId: _selectedCalendarId ?? '',
      triggerEventKeyword: _keywordCtrl.text.trim(),
      normalTriggerDay: _normalDay,
      fallbackCondition: 'if_event_on_day',
      fallbackDay: _fallbackDay,
      fallbackOffsetMinutes: _fallbackOffset,
      windowStartHour: _windowStartHour,
      windowStartMinute: 0,
      windowEndHour: _windowEndHour,
      windowEndMinute: 0,
      message: _messageCtrl.text.trim(),
      isActive: _isActive,
    );
    await SupabaseService.saveReminder(reminder);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(_isNew ? 'Neue Serien-Erinnerung' : 'Erinnerung bearbeiten',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
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
          _Field(controller: _titleCtrl, label: 'Titel', hint: 'z.B. Sportstunde eintragen'),
          const SizedBox(height: 12),
          _Field(
              controller: _messageCtrl,
              label: 'Erinnerungstext',
              hint: 'Was soll die Benachrichtigung sagen?',
              maxLines: 2),
          const SizedBox(height: 20),

          _SectionLabel('Auslöser-Kalender (Outlook)'),
          if (_loadingCalendars)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(color: AppColors.primary),
            )
          else if (_calendars.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Kein Outlook verbunden. In Einstellungen anmelden.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedCalendarId,
              dropdownColor: AppColors.surface,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              hint: const Text('Kalender auswählen...',
                  style: TextStyle(color: AppColors.textDisabled)),
              items: _calendars.map((c) {
                return DropdownMenuItem<String>(
                  value: c['id'] as String,
                  child: Text(c['name'] as String? ?? 'Kalender'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedCalendarId = v),
            ),
          const SizedBox(height: 12),
          _Field(
              controller: _keywordCtrl,
              label: 'Stichwort im Outlook-Termin',
              hint: 'z.B. "Spätdienst"'),
          const SizedBox(height: 20),

          _SectionLabel('Auslösezeitpunkt'),
          _DayPicker(
            label: 'Normaler Tag des Monats',
            value: _normalDay,
            onChanged: (v) => setState(() => _normalDay = v),
          ),
          const SizedBox(height: 8),
          _DayPicker(
            label: 'Ausweichtag (wenn Konflikt)',
            value: _fallbackDay,
            onChanged: (v) => setState(() => _fallbackDay = v),
          ),
          const SizedBox(height: 8),
          _OffsetPicker(
            label: 'Versatz nach Event-Start',
            minutes: _fallbackOffset,
            onChanged: (v) => setState(() => _fallbackOffset = v),
          ),
          const SizedBox(height: 20),

          _SectionLabel('Zeitfenster'),
          Row(
            children: [
              Expanded(
                child: _HourPicker(
                  label: 'Frühestens',
                  hour: _windowStartHour,
                  onChanged: (v) => setState(() => _windowStartHour = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HourPicker(
                  label: 'Spätestens',
                  hour: _windowEndHour,
                  onChanged: (v) => setState(() => _windowEndHour = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
            title: const Text('Aktiv',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            activeThumbColor: AppColors.primary,
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
    _keywordCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }
}

// ── Subwidgets ──────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _Field(
      {required this.controller,
      required this.label,
      required this.hint,
      this.maxLines = 1});

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

class _DayPicker extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _DayPicker(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13))),
        DropdownButton<int>(
          value: value,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          underline: const SizedBox.shrink(),
          items: List.generate(28, (i) => i + 1)
              .map((d) => DropdownMenuItem(value: d, child: Text('$d.')))
              .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ],
    );
  }
}

class _OffsetPicker extends StatelessWidget {
  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  const _OffsetPicker(
      {required this.label, required this.minutes, required this.onChanged});

  static const _options = [0, 30, 60, 90, 120, 180];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13))),
        DropdownButton<int>(
          value: minutes,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          underline: const SizedBox.shrink(),
          items: _options.map((m) {
            final label = m == 0 ? 'Direkt' : '${m}min';
            return DropdownMenuItem(value: m, child: Text(label));
          }).toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ],
    );
  }
}

class _HourPicker extends StatelessWidget {
  final String label;
  final int hour;
  final ValueChanged<int> onChanged;

  const _HourPicker(
      {required this.label, required this.hour, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: hour,
              dropdownColor: AppColors.surface,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              isExpanded: true,
              items: List.generate(24, (i) => i)
                  .map((h) => DropdownMenuItem(
                      value: h, child: Text('${h.toString().padLeft(2, '0')}:00')))
                  .toList(),
              onChanged: (v) => v != null ? onChanged(v) : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Jahres-Checkliste bearbeiten ────────────────────────────────────────────

class YearlyChecklistEditScreen extends StatefulWidget {
  final YearlyChecklist? checklist;

  const YearlyChecklistEditScreen({super.key, this.checklist});

  @override
  State<YearlyChecklistEditScreen> createState() =>
      _YearlyChecklistEditScreenState();
}

class _YearlyChecklistEditScreenState
    extends State<YearlyChecklistEditScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _templateCtrl;
  late int _reminderMonth;

  @override
  void initState() {
    super.initState();
    final c = widget.checklist;
    _titleCtrl = TextEditingController(text: c?.title ?? '');
    _templateCtrl = TextEditingController(text: c?.template ?? '');
    _reminderMonth = c?.reminderMonth ?? DateTime.now().month;
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final checklist = YearlyChecklist(
      id: widget.checklist?.id ?? _uuid.v4(),
      title: _titleCtrl.text.trim(),
      reminderMonth: _reminderMonth,
      template: _templateCtrl.text.trim(),
      lastTriggeredYear: widget.checklist?.lastTriggeredYear ?? 0,
    );
    await SupabaseService.saveYearlyChecklist(checklist);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
            widget.checklist == null
                ? 'Neue Jahres-Aufgabe'
                : 'Jahres-Aufgabe bearbeiten',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
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
          _Field(
              controller: _titleCtrl,
              label: 'Titel',
              hint: 'z.B. Urlaub Teneriffa planen'),
          const SizedBox(height: 12),
          _Field(
              controller: _templateCtrl,
              label: 'Vorlage / Beschreibung',
              hint: 'Was ist zu tun?',
              maxLines: 4),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text('Erinnerungsmonat',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ),
              DropdownButton<int>(
                value: _reminderMonth,
                dropdownColor: AppColors.surface,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
                underline: const SizedBox.shrink(),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(YearlyChecklist.monthName(m)),
                  );
                }).toList(),
                onChanged: (v) =>
                    v != null ? setState(() => _reminderMonth = v) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _templateCtrl.dispose();
    super.dispose();
  }
}
