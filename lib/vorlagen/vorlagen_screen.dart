import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/vorlage.dart';
import '../services/vorlagen_service.dart';
import '../widgets/save_feedback.dart';
import '../widgets/vorlagen_feld.dart';

/// Die gespeicherten Vorlagen ansehen, umbenennen, loeschen.
///
/// Angelegt werden sie nicht hier, sondern dort, wo man sie einstellt: im
/// Termin- und im To-do-Bildschirm mit „Als Vorlage speichern". Hier steht
/// nur, was es gibt — und was weg kann.
class VorlagenScreen extends StatefulWidget {
  const VorlagenScreen({super.key});

  @override
  State<VorlagenScreen> createState() => _VorlagenScreenState();
}

class _VorlagenScreenState extends State<VorlagenScreen> {
  List<Vorlage> _liste = const [];
  bool _laedt = true;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final liste = await VorlagenService.laden();
    if (!mounted) return;
    setState(() {
      _liste = liste;
      _laedt = false;
    });
  }

  Future<void> _umbenennen(Vorlage v) async {
    final ctrl = TextEditingController(text: v.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Vorlage umbenennen',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Name',
            labelStyle: TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (wert) => Navigator.pop(ctx, wert),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Speichern',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty || name.trim() == v.name) return;
    final ok = await VorlagenService.umbenennen(v.id, name);
    if (!mounted) return;
    if (!ok) {
      showInfoSnack(context, 'So heißt schon eine andere Vorlage.');
      return;
    }
    await _laden();
  }

  Future<void> _loeschen(Vorlage v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('„${v.name}" löschen?',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Bestehende Termine und To-dos bleiben, wie sie sind — die '
          'Vorlage erscheint nur nicht mehr als Vorschlag.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await VorlagenService.loeschen(v.id);
    await _laden();
  }

  @override
  Widget build(BuildContext context) {
    final termine = _liste.where((v) => v.art == Vorlagenart.termin).toList()
      ..sort(_nachName);
    final todos = _liste.where((v) => v.art == Vorlagenart.todo).toList()
      ..sort(_nachName);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Vorlagen',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _laedt
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    'Angelegt werden Vorlagen im Termin- oder To-do-'
                    'Bildschirm mit „Als Vorlage speichern". Beim Tippen '
                    'im Titelfeld erscheinen sie dann als Vorschlag.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
                _Gruppe(
                  titel: 'Termine',
                  vorlagen: termine,
                  umbenennen: _umbenennen,
                  loeschen: _loeschen,
                ),
                const SizedBox(height: 16),
                _Gruppe(
                  titel: 'To-dos',
                  vorlagen: todos,
                  umbenennen: _umbenennen,
                  loeschen: _loeschen,
                ),
              ],
            ),
    );
  }

  static int _nachName(Vorlage a, Vorlage b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

class _Gruppe extends StatelessWidget {
  const _Gruppe({
    required this.titel,
    required this.vorlagen,
    required this.umbenennen,
    required this.loeschen,
  });

  final String titel;
  final List<Vorlage> vorlagen;
  final ValueChanged<Vorlage> umbenennen;
  final ValueChanged<Vorlage> loeschen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(titel.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.bold)),
        ),
        if (vorlagen.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Text('Noch keine',
                style: TextStyle(
                    color: AppColors.textDisabled, fontSize: 13)),
          )
        else
          for (final v in vorlagen)
            Card(
              key: ValueKey(v.id),
              color: AppColors.card,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(v.name,
                    style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(
                  [
                    vorlagenKurz(v),
                    if (v.benutzt > 0) '${v.benutzt}× benutzt',
                  ].where((t) => t.isNotEmpty).join(' · '),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 20, color: AppColors.textSecondary),
                      onPressed: () => umbenennen(v),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: AppColors.textSecondary),
                      onPressed: () => loeschen(v),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
