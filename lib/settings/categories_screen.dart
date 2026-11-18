import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../models/app_category.dart';
import '../services/category_service.dart';
import '../services/local_service.dart';
import '../widgets/save_feedback.dart';

/// Kategorien anlegen, umbenennen, einfaerben, loeschen.
///
/// Die Kategorien gehoeren dem Benutzer; bis hierher waren sie vier feste
/// englische Woerter im Code.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _busy = false;

  Future<void> _add() async {
    final used = CategoryService.all.map((c) => c.colorValue).toSet();
    final free = CategoryService.palette.firstWhere(
      (c) => !used.contains(c),
      orElse: () => CategoryService.palette.first,
    );
    final result = await _edit(
        const AppCategory(key: '', label: '', colorValue: 0), free);
    if (result == null) return;
    await CategoryService.add(result.$1, result.$2);
    if (mounted) setState(() {});
  }

  Future<void> _rename(AppCategory cat) async {
    final result = await _edit(cat, cat.colorValue);
    if (result == null) return;
    await CategoryService.update(cat.key,
        label: result.$1, colorValue: result.$2);
    if (mounted) setState(() {});
  }

  /// Gibt (Name, Farbe) zurueck oder null bei Abbruch.
  Future<(String, int)?> _edit(AppCategory cat, int initialColor) {
    return showDialog<(String, int)>(
      context: context,
      builder: (ctx) => _CategoryDialog(
        initialLabel: cat.label,
        initialColor: initialColor,
        isNew: cat.key.isEmpty,
      ),
    );
  }

  Future<void> _delete(AppCategory cat) async {
    if (CategoryService.all.length <= 1) {
      showInfoSnack(context, 'Die letzte Kategorie kann nicht weg.');
      return;
    }
    setState(() => _busy = true);
    int count;
    try {
      count = await LocalService.countByCategory(cat.key);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showInfoSnack(context, 'Konnte nicht nachsehen, was daran haengt: $e');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final others = CategoryService.all.where((c) => c.key != cat.key).toList();
    String? target;

    if (count > 0) {
      // Einfach loeschen wuerde die Eintraege mit einem Schluessel
      // zuruecklassen, den es nicht mehr gibt. Also wird gefragt, wohin.
      target = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('„${cat.label}" löschen?',
              style: const TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count ${count == 1 ? 'Eintrag hängt' : 'Einträge hängen'} '
                'daran. Wohin damit?',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ...others.map((c) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: c.color),
                    ),
                    title: Text(c.label,
                        style:
                            const TextStyle(color: AppColors.textPrimary)),
                    onTap: () => Navigator.pop(ctx, c.key),
                  )),
            ],
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
      if (target == null || !mounted) return;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('„${cat.label}" löschen?',
              style: const TextStyle(color: AppColors.textPrimary)),
          content: const Text('Niemand benutzt sie.',
              style: TextStyle(color: AppColors.textSecondary)),
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
      if (ok != true || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      if (target != null) {
        await LocalService.reassignCategory(cat.key, target);
        await _replaceInBlockingList(cat.key, target);
      }
      await CategoryService.remove(cat.key);
    } catch (e) {
      if (mounted) showInfoSnack(context, 'Löschen fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Die Einstellung "Ganztags-Termine blockieren Auto-Shift" merkt sich
  /// Schluessel. Wandern die Eintraege, muss sie mitwandern.
  Future<void> _replaceInBlockingList(String from, String to) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('blocking_allday_cats') ?? ['vacation'];
    if (!list.contains(from)) return;
    final updated = {...list.where((k) => k != from), to}.toList();
    await prefs.setStringList('blocking_allday_cats', updated);
  }

  @override
  Widget build(BuildContext context) {
    final cats = CategoryService.all;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Kategorien',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Gelten für Termine, To-dos und Jahres-Events. '
              'Gedrückt halten und ziehen ändert die Reihenfolge.',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: cats.length,
              // onReorderItem statt onReorder: der Zielindex ist hier schon
              // um die herausgenommene eigene Zeile bereinigt.
              onReorderItem: (oldIndex, newIndex) async {
                await CategoryService.move(oldIndex, newIndex);
                if (mounted) setState(() {});
              },
              itemBuilder: (context, i) {
                final cat = cats[i];
                return Card(
                  key: ValueKey(cat.key),
                  color: AppColors.card,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: cat.color),
                    ),
                    title: Text(cat.label,
                        style: const TextStyle(color: AppColors.textPrimary)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 20, color: AppColors.textSecondary),
                          onPressed: _busy ? null : () => _rename(cat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: AppColors.textSecondary),
                          onPressed: _busy ? null : () => _delete(cat),
                        ),
                      ],
                    ),
                    onTap: _busy ? null : () => _rename(cat),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  label: const Text('Kategorie hinzufügen',
                      style: TextStyle(color: AppColors.primary)),
                  onPressed: _busy ? null : _add,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final String initialLabel;
  final int initialColor;
  final bool isNew;

  const _CategoryDialog({
    required this.initialLabel,
    required this.initialColor,
    required this.isNew,
  });

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialLabel);
  late int _color = widget.initialColor;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name, _color));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.isNew ? 'Neue Kategorie' : 'Kategorie',
          style: const TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(color: AppColors.textSecondary),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 20),
          const Text('Farbe',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: CategoryService.palette.map((value) {
              final selected = value == _color;
              return GestureDetector(
                onTap: () => setState(() => _color = value),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(value),
                    border: Border.all(
                      color: selected
                          ? AppColors.textPrimary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 18, color: Colors.black)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Speichern',
              style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}
