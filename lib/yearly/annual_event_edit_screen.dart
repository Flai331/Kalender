import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/annual_event.dart';
import '../services/local_service.dart';
import '../widgets/save_feedback.dart';

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

    // Pre-add current/initial year if not present
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
    if (_saving) return;
    if (_nameCtrl.text.trim().isEmpty) {
      showInfoSnack(context, 'Bitte einen Namen eingeben.');
      return;
    }
    setState(() => _saving = true);
    final event = AnnualEvent(
      id: widget.event?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      category: _category,
      colorHex: widget.event?.colorHex,
      occurrences: _occurrences,
    );
    // Lokal speichern + Sync-Queue — funktioniert auch offline.
    bool ok = false;
    try {
      ok = await guardedAction(
        context,
        () => LocalService.saveAnnualEvent(event),
        errorPrefix: 'Jahres-Event speichern fehlgeschlagen',
      );
    } finally {
      // Muss auch bei einem Fehler zurückgesetzt werden, sonst blockiert das
      // Flag jeden weiteren Tippen auf "Speichern".
      if (mounted) setState(() => _saving = false);
    }
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.event == null || _saving) return;
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
    if (confirm != true || !mounted) return;
    setState(() => _saving = true);
    bool ok = false;
    try {
      ok = await guardedAction(
        context,
        () => LocalService.deleteAnnualEvent(widget.event!.id),
        offlineMessage: 'Kein Internet – konnte nicht gelöscht werden. '
            'Bitte später erneut versuchen.',
        errorPrefix: 'Jahres-Event löschen fehlgeschlagen',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (ok && mounted) Navigator.pop(context);
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
      _occurrences[occIndex] =
          isStart ? occ.copyWith(startDate: date) : occ.copyWith(endDate: date);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          widget.event == null ? 'Neues Jahres-Event' : 'Event bearbeiten',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.event != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _saving ? null : _delete,
            ),
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
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Kategorie',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['personal', 'work', 'sport', 'vacation'].map((cat) {
              final selected = _category == cat;
              final color = AppColors.forCategory(cat);
              return ChoiceChip(
                label: Text(cat,
                    style: TextStyle(
                        color: selected ? Colors.white : AppColors.textSecondary,
                        fontSize: 13)),
                selected: selected,
                selectedColor: color,
                backgroundColor: AppColors.surface,
                side: BorderSide(color: selected ? color : AppColors.divider),
                onSelected: (_) => setState(() => _category = cat),
              );
            }).toList(),
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
                            occ.startDate != null ? _fmt(occ.startDate!) : 'Von',
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
                  : _occurrences
                      .map((o) => o.year)
                      .reduce((a, b) => a > b ? a : b);
              setState(
                  () => _occurrences.add(AnnualOccurrence(year: lastYear + 1)));
            },
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
