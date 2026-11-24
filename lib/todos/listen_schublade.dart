import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/todo_liste.dart';
import '../services/category_service.dart';
import '../services/listen_service.dart';

/// Die Schublade mit den Listen — von links herausziehbar, wie die
/// Seitenleiste bei Microsoft To Do: oben alles auf einmal, darunter die
/// einzelnen Listen, zusammengefasst in Ordnern.
///
/// Die Schublade aendert die Listen selbst (anlegen, umbenennen, faerben,
/// einordnen, loeschen) und meldet nur die **Auswahl** nach draussen. Der
/// Bildschirm filtert damit seine To-dos; alles andere zieht ueber
/// [ListenService.revision] nach.
class ListenSchublade extends StatefulWidget {
  const ListenSchublade({
    super.key,
    required this.gewaehlt,
    required this.anzahl,
    required this.waehlen,
  });

  /// Die offene Liste, oder `null` fuer „Alle To-dos".
  final String? gewaehlt;

  /// Wie viele offene To-dos je Liste — Schluessel ist die Kennung der
  /// Liste, in der das To-do wirklich steht
  /// ([ListenService.echteListe]).
  final Map<String, int> anzahl;

  final ValueChanged<String?> waehlen;

  @override
  State<ListenSchublade> createState() => _ListenSchubladeState();
}

class _ListenSchubladeState extends State<ListenSchublade> {
  @override
  void initState() {
    super.initState();
    ListenService.revision.addListener(_aendert);
  }

  @override
  void dispose() {
    ListenService.revision.removeListener(_aendert);
    super.dispose();
  }

  void _aendert() {
    if (mounted) setState(() {});
  }

  int get _gesamt =>
      widget.anzahl.values.fold<int>(0, (a, b) => a + b);

  void _nimm(String? id) {
    widget.waehlen(id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ohneOrdner = ListenService.ohneOrdner;
    final ordner = ListenService.ordner;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.checklist, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Listen',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _Zeile(
                    farbe: AppColors.primary,
                    icon: Icons.all_inbox,
                    name: 'Alle To-dos',
                    anzahl: _gesamt,
                    offen: widget.gewaehlt == null,
                    antippen: () => _nimm(null),
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  for (final l in ohneOrdner) _listenZeile(l),
                  for (final o in ordner) _ordnerBlock(o),
                  const Divider(color: AppColors.divider),
                  ListTile(
                    leading: const Icon(Icons.add,
                        color: AppColors.textSecondary),
                    title: const Text('Neue Liste',
                        style: TextStyle(color: AppColors.textSecondary)),
                    onTap: _neueListe,
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Text(
                        'Ordner entstehen, wenn du eine Liste in einen '
                        'steckst — über das Menü rechts an der Liste.',
                        style: TextStyle(
                            color: AppColors.textDisabled, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listenZeile(TodoListe l, {bool eingerueckt = false}) => _Zeile(
        farbe: Color(l.farbe),
        icon: Icons.circle,
        name: l.name,
        anzahl: widget.anzahl[l.id] ?? 0,
        offen: widget.gewaehlt == l.id,
        eingerueckt: eingerueckt,
        antippen: () => _nimm(l.id),
        menu: _listenMenu(l),
      );

  Widget _listenMenu(TodoListe l) {
    final standard = l.id == ListenService.standardId;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert,
          size: 18, color: AppColors.textDisabled),
      color: AppColors.card,
      onSelected: (wahl) {
        switch (wahl) {
          case 'name':
            _umbenennen(l);
          case 'farbe':
            _faerben(l);
          case 'ordner':
            _einordnen(l);
          case 'weg':
            _loeschen(l);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'name', child: Text('Umbenennen')),
        const PopupMenuItem(value: 'farbe', child: Text('Farbe')),
        PopupMenuItem(
            value: 'ordner',
            child: Text(l.imOrdner ? 'Ordner wechseln' : 'In Ordner')),
        if (!standard)
          const PopupMenuItem(value: 'weg', child: Text('Löschen')),
      ],
    );
  }

  Widget _ordnerBlock(String name) {
    final drin = ListenService.imOrdner(name);
    final summe = drin.fold<int>(0, (a, l) => a + (widget.anzahl[l.id] ?? 0));
    return Theme(
      // Sonst bleibt der Kopf der Gruppe beim Aufklappen in der Akzentfarbe
      // haengen und sieht aus wie ausgewaehlt.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textSecondary,
        leading: const Icon(Icons.folder_outlined,
            size: 20, color: AppColors.textSecondary),
        title: Row(
          children: [
            Expanded(
              child: Text(name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (summe > 0)
              Text('$summe',
                  style: const TextStyle(
                      color: AppColors.textDisabled, fontSize: 12)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  size: 18, color: AppColors.textDisabled),
              color: AppColors.card,
              onSelected: (wahl) {
                if (wahl == 'name') _ordnerUmbenennen(name);
                if (wahl == 'auf') _ordnerAufloesen(name);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'name', child: Text('Umbenennen')),
                PopupMenuItem(value: 'auf', child: Text('Ordner auflösen')),
              ],
            ),
          ],
        ),
        children: [for (final l in drin) _listenZeile(l, eingerueckt: true)],
      ),
    );
  }

  // ── Aendern ───────────────────────────────────────────────────────────────

  /// Die naechste Farbe, die noch keine Liste hat — damit zwei neue Listen
  /// nicht gleich aussehen.
  int _freieFarbe() {
    final belegt = ListenService.alle.map((l) => l.farbe).toSet();
    for (final f in CategoryService.palette) {
      if (!belegt.contains(f)) return f;
    }
    return CategoryService.palette[
        ListenService.alle.length % CategoryService.palette.length];
  }

  Future<void> _neueListe() async {
    final name = await _textDialog(
        titel: 'Neue Liste', hinweis: 'Name der Liste', knopf: 'Anlegen');
    if (name == null || name.isEmpty) return;
    final liste = await ListenService.anlegen(name, farbe: _freieFarbe());
    if (!mounted) return;
    widget.waehlen(liste.id);
  }

  Future<void> _umbenennen(TodoListe l) async {
    final name = await _textDialog(
        titel: 'Liste umbenennen',
        hinweis: 'Name der Liste',
        knopf: 'Übernehmen',
        vorbelegt: l.name);
    if (name == null || name.isEmpty) return;
    await ListenService.umbenennen(l.id, name);
  }

  Future<void> _faerben(TodoListe l) async {
    final farbe = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Farbe',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final f in CategoryService.palette)
              InkWell(
                onTap: () => Navigator.pop(ctx, f),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(f),
                    shape: BoxShape.circle,
                    border: f == l.farbe
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (farbe != null) await ListenService.faerben(l.id, farbe);
  }

  Future<void> _einordnen(TodoListe l) async {
    final ordner = ListenService.ordner;
    final wahl = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.card,
        title: const Text('In welchen Ordner?',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        children: [
          for (final o in ordner)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, o),
              child: Text(o,
                  style: TextStyle(
                      color: o == l.ordner
                          ? AppColors.primary
                          : AppColors.textPrimary)),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '\u0000neu'),
            child: const Text('Neuer Ordner …',
                style: TextStyle(color: AppColors.primary)),
          ),
          if (l.imOrdner)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Aus dem Ordner heraus',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
    if (wahl == null) return;
    if (wahl == '\u0000neu') {
      final name = await _textDialog(
          titel: 'Neuer Ordner',
          hinweis: 'Name des Ordners',
          knopf: 'Anlegen');
      if (name == null || name.isEmpty) return;
      await ListenService.inOrdner(l.id, name);
      return;
    }
    await ListenService.inOrdner(l.id, wahl);
  }

  Future<void> _loeschen(TodoListe l) async {
    final anzahl = widget.anzahl[l.id] ?? 0;
    final ja = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('„${l.name}" löschen?',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
            anzahl == 0
                ? 'Die Liste ist leer.'
                : 'Die $anzahl To-dos darin wandern nach '
                    '„${ListenService.standardVorgabe.name}" — '
                    'gelöscht wird keines.',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen',
                  style: TextStyle(color: AppColors.fixedTag))),
        ],
      ),
    );
    if (ja != true) return;
    await ListenService.loeschen(l.id);
    if (!mounted) return;
    // Die offene Liste gibt es nicht mehr — sonst blieb der Bildschirm leer
    // und zeigte den Namen einer geloeschten Liste.
    if (widget.gewaehlt == l.id) widget.waehlen(null);
  }

  Future<void> _ordnerUmbenennen(String name) async {
    final neu = await _textDialog(
        titel: 'Ordner umbenennen',
        hinweis: 'Name des Ordners',
        knopf: 'Übernehmen',
        vorbelegt: name);
    if (neu == null || neu.isEmpty) return;
    await ListenService.ordnerUmbenennen(name, neu);
  }

  Future<void> _ordnerAufloesen(String name) async {
    await ListenService.ordnerAufloesen(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ordner „$name" aufgelöst. Die Listen bleiben.')));
  }

  Future<String?> _textDialog({
    required String titel,
    required String hinweis,
    required String knopf,
    String vorbelegt = '',
  }) {
    final ctrl = TextEditingController(text: vorbelegt);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(titel,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: hinweis,
            hintStyle: const TextStyle(color: AppColors.textDisabled),
          ),
          onSubmitted: (wert) => Navigator.pop(ctx, wert.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(knopf)),
        ],
      ),
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({
    required this.farbe,
    required this.icon,
    required this.name,
    required this.anzahl,
    required this.offen,
    required this.antippen,
    this.menu,
    this.eingerueckt = false,
  });

  final Color farbe;
  final IconData icon;
  final String name;
  final int anzahl;
  final bool offen;
  final VoidCallback antippen;
  final Widget? menu;
  final bool eingerueckt;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      // Die Farbe gehoert an die Zeile selbst: in einen gefaerbten
      // Kasten gesteckt verschluckt sie den Tipp-Schatten.
      tileColor: offen ? AppColors.primary.withValues(alpha: 0.12) : null,
      contentPadding: EdgeInsets.only(left: eingerueckt ? 32 : 16, right: 4),
      leading: Icon(icon, size: icon == Icons.circle ? 14 : 20,
          color: farbe),
      title: Text(name,
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: offen ? FontWeight.w700 : FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (anzahl > 0)
            Text('$anzahl',
                style: const TextStyle(
                    color: AppColors.textDisabled, fontSize: 12)),
          ?menu,
          if (menu == null) const SizedBox(width: 12),
        ],
      ),
      onTap: antippen,
    );
  }
}
