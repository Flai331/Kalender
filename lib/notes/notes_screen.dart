import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/week_note.dart';
import '../services/local_service.dart';
import '../widgets/save_feedback.dart';
import '../widgets/feedback_button.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

/// Ein Ziel im Bildschirm: Textfeld und Haken gehoeren zusammen, darum
/// liegen sie in einem Objekt und koennen nicht auseinanderlaufen.
class _ZielZeile {
  final TextEditingController ctrl;
  bool erledigt;

  _ZielZeile({String text = '', this.erledigt = false})
      : ctrl = TextEditingController(text: text);
}

class _NotesScreenState extends State<NotesScreen> {
  late String _weekKey;
  bool _loading = true;

  final TextEditingController _contentCtrl = TextEditingController();
  final List<_ZielZeile> _ziele = [];

  @override
  void initState() {
    super.initState();
    _weekKey = WeekNote.keyForDate(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    final note = await LocalService.getWeekNote(_weekKey);
    setState(() {
      _contentCtrl.text = note.content;
      for (final z in _ziele) {
        z.ctrl.dispose();
      }
      _ziele.clear();
      for (final g in note.goals) {
        _ziele.add(_ZielZeile(text: g.text, erledigt: g.done));
      }
      _loading = false;
    });
  }

  WeekNote _aktuellerStand() => WeekNote(
        weekKey: _weekKey,
        content: _contentCtrl.text,
        goals: _ziele
            .where((z) => z.ctrl.text.trim().isNotEmpty)
            .map((z) =>
                WeekGoal(text: z.ctrl.text.trim(), done: z.erledigt))
            .toList(),
      );

  /// `still` speichert ohne Rueckmeldung — das ist der Weg fuer den Haken:
  /// ein Tipp darf nicht erst durch "Speichern" bestaetigt werden muessen.
  Future<void> _save({bool still = false}) async {
    // Speichert in die lokale Datenbank, aus der die Ansichten lesen.
    final ok = await guardedAction(
      context,
      () => LocalService.saveWeekNote(_aktuellerStand()),
      errorPrefix: 'Notiz speichern fehlgeschlagen',
    );
    if (ok && mounted && !still) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gespeichert'),
          backgroundColor: AppColors.surface,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// Hakt ein Ziel ab oder wieder auf und sichert es sofort — mitsamt dem,
  /// was gerade in den Textfeldern steht.
  Future<void> _toggleZiel(int index) async {
    setState(() => _ziele[index].erledigt = !_ziele[index].erledigt);
    if (_ziele[index].ctrl.text.trim().isEmpty) return;
    await _save(still: true);
  }

  void _addGoal() {
    if (_ziele.length >= 5) return;
    setState(() => _ziele.add(_ZielZeile()));
  }

  void _removeGoal(int index) {
    setState(() {
      _ziele[index].ctrl.dispose();
      _ziele.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final offen = _ziele.where((z) => !z.erledigt).length;
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
                  title: _ziele.isEmpty
                      ? 'Wochenziele'
                      : 'Wochenziele · $offen offen',
                  trailing: _ziele.length < 5
                      ? IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: AppColors.primary, size: 20),
                          onPressed: _addGoal,
                        )
                      : null,
                ),
                if (_ziele.isEmpty)
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
                ...List.generate(_ziele.length, (i) {
                  final ziel = _ziele[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        // Der Haken: das war vorher ein totes Zeichen.
                        IconButton(
                          icon: Icon(
                            ziel.erledigt
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: ziel.erledigt
                                ? AppColors.primary
                                : AppColors.textDisabled,
                            size: 22,
                          ),
                          onPressed: () => _toggleZiel(i),
                          tooltip: ziel.erledigt
                              ? 'Wieder offen'
                              : 'Erledigt',
                          visualDensity: VisualDensity.compact,
                        ),
                        Expanded(
                          child: TextField(
                            controller: ziel.ctrl,
                            style: TextStyle(
                              color: ziel.erledigt
                                  ? AppColors.textDisabled
                                  : AppColors.textPrimary,
                              fontSize: 14,
                              decoration: ziel.erledigt
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: AppColors.textDisabled,
                            ),
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
                          visualDensity: VisualDensity.compact,
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
    for (final z in _ziele) {
      z.ctrl.dispose();
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
          ?trailing,
        ],
      ),
    );
  }
}
