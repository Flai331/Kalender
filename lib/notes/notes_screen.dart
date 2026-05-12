import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/week_note.dart';
import '../services/supabase_service.dart';
import '../widgets/feedback_button.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late String _weekKey;
  bool _loading = true;

  final TextEditingController _contentCtrl = TextEditingController();
  final List<TextEditingController> _goalCtrls = [];

  @override
  void initState() {
    super.initState();
    _weekKey = WeekNote.keyForDate(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    final note = await SupabaseService.getWeekNote(_weekKey);
    setState(() {
      _contentCtrl.text = note.content;
      _goalCtrls.clear();
      for (final g in note.goals) {
        _goalCtrls.add(TextEditingController(text: g));
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    final goals = _goalCtrls
        .map((c) => c.text.trim())
        .where((g) => g.isNotEmpty)
        .toList();
    final updated = WeekNote(
      weekKey: _weekKey,
      content: _contentCtrl.text,
      goals: goals,
    );
    await SupabaseService.saveWeekNote(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gespeichert'),
          backgroundColor: AppColors.surface,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _addGoal() {
    if (_goalCtrls.length >= 5) return;
    setState(() => _goalCtrls.add(TextEditingController()));
  }

  void _removeGoal(int index) {
    setState(() {
      _goalCtrls[index].dispose();
      _goalCtrls.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Wochennotizen',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(_weekKey,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Wochenziele
                _SectionHeader(
                  title: 'Wochenziele',
                  trailing: _goalCtrls.length < 5
                      ? IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: AppColors.primary, size: 20),
                          onPressed: _addGoal,
                        )
                      : null,
                ),
                if (_goalCtrls.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: _addGoal,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.divider,
                              style: BorderStyle.solid),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: AppColors.textDisabled,
                                size: 16),
                            SizedBox(width: 6),
                            Text('Ziel hinzufügen',
                                style: TextStyle(
                                    color: AppColors.textDisabled,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ...List.generate(_goalCtrls.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Text('○ ',
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 16)),
                        Expanded(
                          child: TextField(
                            controller: _goalCtrls[i],
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Ziel ${i + 1}...',
                              hintStyle: const TextStyle(
                                  color: AppColors.textDisabled),
                              filled: true,
                              fillColor: AppColors.card,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 18, color: AppColors.textDisabled),
                          onPressed: () => _removeGoal(i),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Freitext-Notiz
                const _SectionHeader(title: 'Notizen'),
                TextField(
                  controller: _contentCtrl,
                  maxLines: 12,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Gedanken zur Woche, Rückblick, Ideen...',
                    hintStyle:
                        const TextStyle(color: AppColors.textDisabled),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    for (final c in _goalCtrls) {
      c.dispose();
    }
    super.dispose();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          if (trailing != null) const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
