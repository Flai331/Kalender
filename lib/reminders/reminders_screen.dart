import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/series_reminder.dart';
import '../models/yearly_checklist.dart';
import '../services/supabase_service.dart';
import 'reminder_edit_screen.dart';
import '../widgets/feedback_button.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('Erinnerungen',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          actions: const [FeedbackIconButton()],
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Serien-Erinnerungen'),
              Tab(text: 'Jahres-Aufgaben'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SeriesRemindersTab(),
            _YearlyChecklistsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Serien-Erinnerungen ───────────────────────────────────────────────

class _SeriesRemindersTab extends StatelessWidget {
  const _SeriesRemindersTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SeriesReminder>>(
      stream: SupabaseService.remindersStream(),
      builder: (ctx, snap) {
        final reminders = snap.data ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: reminders.isEmpty
              ? _EmptyState(
                  icon: Icons.notifications_outlined,
                  message: 'Noch keine Serien-Erinnerungen',
                  hint:
                      'Erstelle Regeln, die sich nach deinen Outlook-Terminen richten',
                  onAdd: () => _openEdit(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: reminders.length,
                  itemBuilder: (ctx, i) {
                    final r = reminders[i];
                    return _ReminderTile(
                      reminder: r,
                      onTap: () => _openEdit(context, r),
                      onToggle: (v) {
                        SupabaseService.saveReminder(r.copyWith(isActive: v));
                      },
                      onDelete: () =>
                          SupabaseService.deleteReminder(r.id),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'reminders_fab',
            onPressed: () => _openEdit(context),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  void _openEdit(BuildContext context, [SeriesReminder? reminder]) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ReminderEditScreen(reminder: reminder)),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final SeriesReminder reminder;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _ReminderTile({
    required this.reminder,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(reminder.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red.withValues(alpha: 0.2),
        child: const Icon(Icons.delete, color: Colors.redAccent),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications_active_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reminder.title,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(
                      'Am ${reminder.normalTriggerDay}., Ausweich: ${reminder.fallbackDay}. | '
                      '${reminder.windowStartHour}:00–${reminder.windowEndHour}:00 Uhr',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: reminder.isActive,
                onChanged: onToggle,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab 2: Jahres-Aufgaben ──────────────────────────────────────────────────

class _YearlyChecklistsTab extends StatelessWidget {
  const _YearlyChecklistsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<YearlyChecklist>>(
      stream: SupabaseService.yearlyChecklistsStream(),
      builder: (ctx, snap) {
        final lists = snap.data ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: lists.isEmpty
              ? _EmptyState(
                  icon: Icons.event_repeat,
                  message: 'Keine Jahres-Aufgaben',
                  hint:
                      'z.B. "Urlaub planen" – erscheint jedes Jahr im gewählten Monat',
                  onAdd: () => _openEdit(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: lists.length,
                  itemBuilder: (ctx, i) {
                    final c = lists[i];
                    return _ChecklistTile(
                      checklist: c,
                      onTap: () => _openEdit(context, c),
                      onDelete: () =>
                          SupabaseService.deleteYearlyChecklist(c.id),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'checklists_fab',
            onPressed: () => _openEdit(context),
            backgroundColor: AppColors.vacation,
            child: const Icon(Icons.add, color: Colors.black87),
          ),
        );
      },
    );
  }

  void _openEdit(BuildContext context, [YearlyChecklist? checklist]) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              YearlyChecklistEditScreen(checklist: checklist)),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final YearlyChecklist checklist;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChecklistTile({
    required this.checklist,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(checklist.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red.withValues(alpha: 0.2),
        child: const Icon(Icons.delete, color: Colors.redAccent),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: AppColors.vacation, width: 3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_repeat,
                  color: AppColors.vacation, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(checklist.title,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(
                      'Erinnerung im ${YearlyChecklist.monthName(checklist.reminderMonth)}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textDisabled, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gemeinsam ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String hint;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.hint,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(hint,
                style: const TextStyle(
                    color: AppColors.textDisabled, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Neu erstellen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
