import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/vorlage.dart';
import '../services/category_service.dart';
import '../services/vorlagen_service.dart';
import '../vorlagen/vorlagensuche.dart';

/// Das Titelfeld, das die Vorlagen kennt.
///
/// Sieht aus wie jedes andere Titelfeld und verhaelt sich auch so — nur
/// dass beim Tippen darunter die passenden Vorlagen erscheinen. Wird eine
/// genommen, setzt sie den Titel und meldet sich ueber [gewaehlt]; den
/// Rest des Formulars fuellt der Bildschirm, dem das Feld gehoert.
class VorlagenFeld extends StatefulWidget {
  const VorlagenFeld({
    super.key,
    required this.controller,
    required this.art,
    required this.label,
    required this.hint,
    required this.gewaehlt,
  });

  final TextEditingController controller;

  /// Vorlagen welcher Art vorgeschlagen werden — Termine oder To-dos.
  final Vorlagenart art;

  final String label;
  final String hint;

  /// Eine Vorlage wurde aus der Liste genommen.
  final ValueChanged<Vorlage> gewaehlt;

  @override
  State<VorlagenFeld> createState() => _VorlagenFeldState();
}

class _VorlagenFeldState extends State<VorlagenFeld> {
  final FocusNode _fokus = FocusNode();
  List<Vorlage> _vorrat = const [];

  @override
  void initState() {
    super.initState();
    _laden();
    VorlagenService.revision.addListener(_laden);
  }

  @override
  void dispose() {
    VorlagenService.revision.removeListener(_laden);
    _fokus.dispose();
    super.dispose();
  }

  Future<void> _laden() async {
    final liste = await VorlagenService.fuer(widget.art);
    if (!mounted) return;
    setState(() => _vorrat = liste);
  }

  void _nimm(Vorlage v) {
    // Den Titel hat die Vorschlagsliste schon gesetzt; hier kommt alles
    // Uebrige. Der Zaehler merkt sich, was oft gebraucht wird.
    widget.gewaehlt(v);
    VorlagenService.benutzt(v.id);
    _fokus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Vorlage>(
      textEditingController: widget.controller,
      focusNode: _fokus,
      displayStringForOption: (v) => v.name,
      optionsBuilder: (wert) => Vorlagensuche.passend(_vorrat, wert.text),
      onSelected: _nimm,
      fieldViewBuilder: (ctx, ctrl, fokus, abgeschickt) => TextField(
        controller: ctrl,
        focusNode: fokus,
        onSubmitted: (_) => abgeschickt(),
        textInputAction: TextInputAction.done,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textDisabled),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      optionsViewBuilder: (ctx, waehlen, vorschlaege) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Material(
            color: AppColors.card,
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: vorschlaege.length,
                itemBuilder: (_, i) {
                  final v = vorschlaege.elementAt(i);
                  return _Vorschlag(vorlage: v, angetippt: () => waehlen(v));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Vorschlag extends StatelessWidget {
  const _Vorschlag({required this.vorlage, required this.angetippt});

  final Vorlage vorlage;
  final VoidCallback angetippt;

  @override
  Widget build(BuildContext context) {
    final zeile = vorlagenKurz(vorlage);
    return InkWell(
      onTap: angetippt,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.bookmark_outline,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vorlage.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                  if (zeile.isNotEmpty)
                    Text(zeile,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Die Vorlage in einer Zeile: Dauer und Fahrzeiten, damit man zwei
/// aehnliche Vorlagen unterscheiden kann, ohne sie zu oeffnen.
String vorlagenKurz(Vorlage v) {
  final teile = <String>[];
  final dauer = v.art == Vorlagenart.termin
      ? v.dauerMinuten
      : v.felder['estimatedMinutes'] as int?;
  if (dauer != null && dauer > 0) teile.add(_dauer(dauer));
  final vor = v.art == Vorlagenart.termin
      ? v.felder['travelBeforeOverride'] as int?
      : v.felder['travelMinutesBefore'] as int?;
  final nach = v.art == Vorlagenart.termin
      ? v.felder['travelAfterOverride'] as int?
      : v.felder['travelMinutesAfter'] as int?;
  if ((vor ?? 0) > 0 || (nach ?? 0) > 0) {
    teile.add('${vor ?? 0}/${nach ?? 0} Min Fahrt');
  }
  final kategorie = v.felder['category'];
  if (kategorie is String && kategorie.isNotEmpty) {
    teile.add(CategoryService.labelOf(kategorie));
  }
  return teile.join(' · ');
}

String _dauer(int minuten) {
  if (minuten < 60) return '$minuten Min';
  final std = minuten ~/ 60;
  final rest = minuten % 60;
  return rest == 0 ? '$std Std' : '$std Std $rest Min';
}
