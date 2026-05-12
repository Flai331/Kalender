import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../models/calendar_event.dart';
import '../services/auth_service.dart';
import '../services/daylight_service.dart';
import '../services/feedback_service.dart';
import '../services/ics_service.dart';
import '../services/reminder_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _icsController = TextEditingController();
  bool _icsSaved = false;
  bool _icsTesting = false;
  String? _icsError;

  List<String> _blockingAllDayCats = ['vacation'];
  int _daylightSunrise = 6;
  int _daylightSunset = 20;

  @override
  void initState() {
    super.initState();
    _loadIcsUrl();
    _loadConstraintSettings();
  }

  @override
  void dispose() {
    _icsController.dispose();
    super.dispose();
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

  Future<void> _loadIcsUrl() async {
    final url = await IcsService.getSavedUrl();
    if (mounted && url != null) {
      setState(() {
        _icsController.text = url;
        _icsSaved = url.isNotEmpty;
      });
    }
  }

  Future<void> _saveIcsUrl() async {
    final url = _icsController.text.trim();
    if (url.isEmpty) return;
    setState(() { _icsTesting = true; _icsError = null; });

    // URL speichern, dann testen
    await IcsService.saveUrl(url);
    final testEvents = await IcsService.fetchEvents();

    if (mounted) {
      setState(() {
        _icsTesting = false;
        if (testEvents.isEmpty && url.isNotEmpty) {
          _icsError = 'Keine Events gefunden – URL prüfen';
          _icsSaved = false;
        } else {
          _icsSaved = true;
          _icsError = null;
        }
      });
      if (_icsSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${testEvents.length} Termine geladen'),
            backgroundColor: AppColors.started,
          ),
        );
      }
    }
  }

  Future<void> _clearIcsUrl() async {
    await IcsService.clearUrl();
    if (mounted) {
      setState(() {
        _icsController.clear();
        _icsSaved = false;
        _icsError = null;
      });
    }
  }

  Future<void> _testNotification() async {
    await ReminderService.showTestNotification(
      'Test-Erinnerung',
      'Die Benachrichtigungen funktionieren korrekt!',
    );
  }

  void _showIcsHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Outlook ICS-Link',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'So findest du deinen Outlook ICS-Link:\n\n'
          '1. Outlook im Browser öffnen\n'
          '2. Kalender-Symbol klicken\n'
          '3. Einstellungen → Kalender freigeben\n'
          '4. Kalender auswählen → "Freigeben"\n'
          '5. "ICS-Link" kopieren\n\n'
          'Der Link beginnt mit webcal:// oder https://',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
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

          // Outlook ICS
          _Section(
            title: 'Outlook Kalender (ICS)',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ICS-Kalender-Link',
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline,
                          color: AppColors.textSecondary, size: 18),
                      onPressed: _showIcsHelp,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: TextField(
                  controller: _icsController,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'webcal://outlook.live.com/owa/calendar/...',
                    hintStyle: const TextStyle(
                        color: AppColors.textDisabled, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    errorText: _icsError,
                    suffixIcon: _icsSaved
                        ? const Icon(Icons.check_circle,
                            color: AppColors.started, size: 18)
                        : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    if (_icsSaved)
                      TextButton(
                        onPressed: _clearIcsUrl,
                        child: const Text('Entfernen',
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 13)),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _icsTesting ? null : _saveIcsUrl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _icsTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Speichern & Testen',
                              style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
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
