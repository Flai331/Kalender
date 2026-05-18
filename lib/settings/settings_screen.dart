import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../calendars/calendar_list_screen.dart';
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
  bool _outlookAllowTodoDrop = false;

  int _daylightSunrise = 6;
  int _daylightSunset = 20;

  @override
  void initState() {
    super.initState();
    _loadOutlookSetting();
    _loadConstraintSettings();
  }

  Future<void> _loadOutlookSetting() async {
    final outlook = await IcsService.getOutlookAllowTodoDrop();
    if (mounted) {
      setState(() {
        _outlookAllowTodoDrop = outlook;
      });
    }
  }

  Future<void> _loadConstraintSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _daylightSunrise = prefs.getInt('daylight_sunrise') ?? 6;
      _daylightSunset = prefs.getInt('daylight_sunset') ?? 20;
    });
  }

  Future<void> _toggleOutlookAllowTodoDrop(bool value) async {
    await IcsService.setOutlookAllowTodoDrop(value);
    setState(() => _outlookAllowTodoDrop = value);
  }

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

          // Kalender
          _Section(
            title: 'Kalender',
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_month,
                    color: AppColors.primary, size: 22),
                title: const Text('Kalender verwalten',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                subtitle: const Text('Erstellen, bearbeiten, ICS-Feeds',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CalendarListScreen()),
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
                activeThumbColor: AppColors.primary,
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
