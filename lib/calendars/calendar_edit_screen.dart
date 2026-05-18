import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/calendar.dart';
import '../models/ics_source.dart';
import '../services/calendar_service.dart';

const _uuid = Uuid();

const _presetColors = <int>[
  0xFFFF6D00, // orange
  0xFF448AFF, // blue
  0xFF69F0AE, // green
  0xFFFFD740, // yellow
  0xFFFF5252, // red
  0xFF6C63FF, // purple
  0xFF00BCD4, // cyan
  0xFF9E9E9E, // grey
];

class CalendarEditScreen extends StatefulWidget {
  final Calendar? calendar;
  const CalendarEditScreen({super.key, this.calendar});

  @override
  State<CalendarEditScreen> createState() => _CalendarEditScreenState();
}

class _CalendarEditScreenState extends State<CalendarEditScreen> {
  late TextEditingController _nameCtrl;
  late int _color;
  late bool _blocksAutoShift;
  late List<IcsSource> _feeds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.calendar;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _color = c?.color ?? _presetColors[0];
    _blocksAutoShift = c?.blocksAutoShift ?? false;
    _feeds = List.from(c?.icsFeeds ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _saving) return;
    _saving = true;
    final cal = Calendar(
      id: widget.calendar?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      color: _color,
      icsFeeds: _feeds,
      blocksAutoShift: _blocksAutoShift,
    );
    await CalendarService.saveCalendar(cal);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.calendar == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Kalender löschen?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
            'Termine dieses Kalenders bleiben erhalten, haben dann aber keinen Kalender.',
            style: TextStyle(color: AppColors.textSecondary)),
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
      await CalendarService.deleteCalendar(widget.calendar!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _addUrl() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('ICS-Feed hinzufügen',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: AppColors.textSecondary))),
            const SizedBox(height: 8),
            TextField(
                controller: urlCtrl,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12),
                decoration: const InputDecoration(
                    labelText: 'webcal:// oder https://',
                    labelStyle: TextStyle(color: AppColors.textSecondary))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              child: const Text('Hinzufügen')),
        ],
      ),
    );
    if (ok != true) return;
    final url = urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _feeds.add(IcsSource(
          id: _uuid.v4(),
          name: nameCtrl.text.trim().isEmpty ? url : nameCtrl.text.trim(),
          url: url,
        )));
  }

  Future<void> _addFile() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['ics']);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() => _feeds.add(IcsSource(
          id: _uuid.v4(),
          name: result.files.single.name.replaceAll('.ics', ''),
          url: path,
          isFile: true,
        )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
            widget.calendar == null
                ? 'Neuer Kalender'
                : 'Kalender bearbeiten',
            style: const TextStyle(color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.calendar != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _delete,
            ),
          TextButton(
            onPressed: _save,
            child: const Text('Speichern',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold)),
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
          const Text('Farbe',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: _presetColors.map((c) {
              final selected = _color == c;
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(c),
                    border: selected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
                'Ganztags-Termine blockieren Auto-Shift',
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 14)),
            value: _blocksAutoShift,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => _blocksAutoShift = v),
          ),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(
                child: Text('ICS-Feeds',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
              TextButton.icon(
                icon: const Icon(Icons.link,
                    size: 14, color: AppColors.primary),
                label: const Text('URL',
                    style: TextStyle(
                        color: AppColors.primary, fontSize: 12)),
                onPressed: _addUrl,
              ),
              TextButton.icon(
                icon: const Icon(Icons.attach_file,
                    size: 14, color: AppColors.primary),
                label: const Text('Datei',
                    style: TextStyle(
                        color: AppColors.primary, fontSize: 12)),
                onPressed: _addFile,
              ),
            ],
          ),
          ..._feeds.asMap().entries.map((e) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    e.value.isFile ? Icons.attach_file : Icons.link,
                    size: 16,
                    color: AppColors.textSecondary),
                title: Text(e.value.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13)),
                subtitle: Text(e.value.url,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.textSecondary),
                  onPressed: () =>
                      setState(() => _feeds.removeAt(e.key)),
                ),
              )),
          if (_feeds.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Keine Feeds — nur manuelle Termine.',
                  style: TextStyle(
                      color: AppColors.textDisabled, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
