import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../models/calendar_event.dart';
import '../models/ics_source.dart';
import '../services/auth_service.dart';
import '../services/daylight_service.dart';
import '../services/feedback_service.dart';
import '../services/ics_service.dart';
import '../services/reminder_service.dart';
import '../widgets/feedback_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<IcsSource> _sources = [];
  bool _sourcesLoading = true;
  bool _outlookAllowTodoDrop = false;

  List<String> _blockingAllDayCats = ['vacation'];
  int _daylightSunrise = 6;
  int _daylightSunset = 20;

  @override
  void initState() {
    super.initState();
    _loadSources();
    _loadConstraintSettings();
  }

  Future<void> _loadSources() async {
    final sources = await IcsService.getSources();
    final outlook = await IcsService.getOutlookAllowTodoDrop();
    if (mounted) setState(() {
      _sources = sources;
      _sourcesLoading = false;
      _outlookAllowTodoDrop = outlook;
    });
  }

  Future<void> _loadConstraintSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _blockingAllDayCats =
          prefs.getStringList('blocking_allday_cats') ?? ['vacation'];
      _daylightSunrise = prefs.getInt('daylight_sunrise') ?? 6;
      _daylightSunset = prefs.getInt('daylight_sunset') ?? 20;
    });
  }

  Future<void> _saveBlockingCats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocking_allday_cats', _blockingAllDayCats);
  }

  Future<void> _toggleIcsAllowTodoDrop(IcsSource src, bool value) async {
    final sources = await IcsService.getSources();
    final updated = sources.map((s) =>
        s.id == src.id ? s.copyWith(allowTodoDrop: value) : s).toList();
    await IcsService.saveSources(updated);
    await _loadSources();
  }

  Future<void> _toggleOutlookAllowTodoDrop(bool value) async {
    await IcsService.setOutlookAllowTodoDrop(value);
    setState(() => _outlookAllowTodoDrop = value);
  }

  Future<void> _addUrl() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('URL hinzufügen',
            style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: _inputDeco('Name (z.B. Outlook)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                decoration: _inputDeco('webcal://outlook.live.com/...'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final url = urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _sourcesLoading = true);
    await IcsService.addUrl(url, nameCtrl.text.trim());
    await _loadSources();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kalender hinzugefügt'),
            backgroundColor: AppColors.started),
      );
    }
  }

  Future<void> _addFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ics'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    if (!mounted) return;

    final nameCtrl = TextEditingController(
        text: result.files.single.name.replaceAll('.ics', ''));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Datei hinzufügen',
            style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: nameCtrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: _inputDeco('Name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _sourcesLoading = true);
    await IcsService.addFile(path, nameCtrl.text.trim());
    await _loadSources();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ICS-Datei hinzugefügt'),
            backgroundColor: AppColors.started),
      );
    }
  }

  static const List<int> _presetColors = [
    0xFF6C63FF, 0xFF448AFF, 0xFF00BCD4, 0xFF4CAF50,
    0xFF8BC34A, 0xFFFFD740, 0xFFFF9800, 0xFFFF5252,
    0xFFE040FB, 0xFFFF4081, 0xFF795548, 0xFF607D8B,
  ];

  Future<void> _pickColor(IcsSource src) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Farbe für ${src.name}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _presetColors.map((c) {
            final isSelected = src.color == c;
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, c),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 2.5)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
    if (picked == null) return;
    final sources = await IcsService.getSources();
    final updated = sources.map((s) =>
        s.id == src.id ? s.copyWith(color: picked) : s).toList();
    await IcsService.saveSources(updated);
    await _loadSources();
  }

  Future<void> _removeSource(String id) async {
    await IcsService.removeSource(id);
    await _loadSources();
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textDisabled, fontSize: 12),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      );

  Future<void> _testNotification() async {
    await ReminderService.showTestNotification(
      'Test-Erinnerung',
      'Die Benachrichtigungen funktionieren korrekt!',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Einstellungen',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: const [FeedbackIconButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Konto
          _Section(
            title: 'Konto',
            children: [
              _InfoTile(
                icon: Icons.fingerprint,
                title: 'Anonyme ID',
                subtitle: AuthService.userId ?? 'Nicht angemeldet',
                color: AppColors.primary,
              ),
              _InfoTile(
                icon: Icons.cloud_outlined,
                title: 'Cloud Sync',
                subtitle: AuthService.userId != null
                    ? 'Verbunden – Daten in Supabase gespeichert'
                    : 'Nicht verbunden',
                color: AppColors.started,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ICS Kalender
          _Section(
            title: 'Kalender (ICS)',
            children: [
              if (_sourcesLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2)),
                )
              else if (_sources.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('Noch kein Kalender hinzugefügt',
                      style: TextStyle(
                          color: AppColors.textDisabled, fontSize: 13)),
                )
              else
                ..._sources.map((src) {
                  final srcColor = src.color != null
                      ? Color(src.color!)
                      : AppColors.primary;
                  return ListTile(
                    leading: GestureDetector(
                      onTap: () => _pickColor(src),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: srcColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white24, width: 1),
                        ),
                        child: Icon(
                          src.isFile
                              ? Icons.insert_drive_file_outlined
                              : Icons.calendar_month_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                    title: Text(src.name,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14)),
                    subtitle: Text(
                      src.url,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Todo-Drop erlauben',
                          child: Switch(
                            value: src.allowTodoDrop,
                            onChanged: (v) => _toggleIcsAllowTodoDrop(src, v),
                            activeColor: AppColors.primary,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          onPressed: () => _removeSource(src.id),
                          tooltip: 'Entfernen',
                        ),
                      ],
                    ),
                  );
                }),
              const Divider(height: 1, color: AppColors.background),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addUrl,
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('URL', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addFile,
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Datei', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Outlook
          _Section(
            title: 'Outlook',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.mail_outline,
                    color: AppColors.primary, size: 22),
                title: const Text('Todo-Drop erlauben',
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
                subtitle: const Text(
                    'Todos in Outlook-Termine ziehen erlauben',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                value: _outlookAllowTodoDrop,
                onChanged: _toggleOutlookAllowTodoDrop,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Benachrichtigungen
          _Section(
            title: 'Benachrichtigungen',
            children: [
              _ActionTile(
                icon: Icons.notifications_outlined,
                iconColor: AppColors.primary,
                title: 'Test-Benachrichtigung',
                subtitle: 'Prüfen ob Notifications funktionieren',
                actionLabel: 'Testen',
                actionColor: AppColors.primary,
                onAction: _testNotification,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Feedback
          _Section(
            title: 'Support',
            children: [
              _ActionTile(
                icon: Icons.bug_report_outlined,
                iconColor: AppColors.vacation,
                title: 'Fehler melden',
                subtitle: 'Screenshot + Protokoll automatisch angehängt',
                actionLabel: 'Melden',
                actionColor: AppColors.vacation,
                onAction: () => FeedbackService.showReportDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Planungseinschränkungen ──────────────────────────────
          const Divider(color: AppColors.divider),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Auto-Shift Einschränkungen',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Blockierende Ganztags-Kategorien
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Ganztags-Termine blockieren Auto-Shift:',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          ...EventCategory.values.map((cat) {
            final name = cat.name;
            final label = switch (cat) {
              EventCategory.work     => 'Arbeit',
              EventCategory.sport    => 'Sport',
              EventCategory.vacation => 'Urlaub',
              EventCategory.personal => 'Persönlich',
            };
            return CheckboxListTile(
              title: Text(label,
                  style: const TextStyle(color: AppColors.textPrimary)),
              value: _blockingAllDayCats.contains(name),
              activeColor: AppColors.primary,
              tileColor: AppColors.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              onChanged: (on) {
                setState(() {
                  if (on == true) {
                    _blockingAllDayCats.add(name);
                  } else {
                    _blockingAllDayCats.remove(name);
                  }
                });
                _saveBlockingCats();
              },
            );
          }),

          const SizedBox(height: 12),

          // Tageslicht-Fallback
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tageslicht-Fallback (wenn kein GPS):',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _daylightSunrise,
                    decoration: InputDecoration(
                      labelText: 'Sonnenaufgang',
                      labelStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: List.generate(24, (h) => DropdownMenuItem(
                      value: h,
                      child: Text('${h.toString().padLeft(2, '0')}:00'),
                    )),
                    onChanged: (h) {
                      if (h == null) return;
                      setState(() => _daylightSunrise = h);
                      DaylightService.saveSettings(_daylightSunrise, _daylightSunset);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _daylightSunset,
                    decoration: InputDecoration(
                      labelText: 'Sonnenuntergang',
                      labelStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: List.generate(24, (h) => DropdownMenuItem(
                      value: h,
                      child: Text('${h.toString().padLeft(2, '0')}:00'),
                    )),
                    onChanged: (h) {
                      if (h == null) return;
                      setState(() => _daylightSunset = h);
                      DaylightService.saveSettings(_daylightSunrise, _daylightSunset);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Subwidgets ──────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
              color: AppColors.textDisabled,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      subtitle: Text(
        subtitle,
        style:
            const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onAction;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(title,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: TextButton(
        onPressed: onAction,
        child: Text(actionLabel,
            style: TextStyle(
                color: actionColor, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
