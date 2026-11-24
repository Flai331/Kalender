import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/listen_service.dart';

/// Auswahl der Liste, in der ein To-do steht — dieselbe Reihe Knoepfe wie
/// bei den Kategorien, damit das Formular nicht zwei Auswahl-Arten hat.
///
/// Steht eine Liste in einem Ordner, steht der Ordner mit davor: zwei
/// Listen duerfen „Einkauf" heissen, solange sie in verschiedenen Ordnern
/// liegen, und dann muss man sie hier unterscheiden koennen.
class ListenPicker extends StatelessWidget {
  const ListenPicker({
    super.key,
    required this.gewaehlt,
    required this.onChanged,
  });

  /// Die Kennung der gewaehlten Liste. Leer oder unbekannt heisst
  /// Standardliste — genau wie am To-do selbst.
  final String? gewaehlt;

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ListenService.revision,
      builder: (context, _, child) {
        final offen = ListenService.echteListe(gewaehlt);
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: ListenService.alle.map((l) {
            final ist = l.id == offen;
            final farbe = Color(l.farbe);
            return ChoiceChip(
              label: Text(l.imOrdner ? '${l.ordner} · ${l.name}' : l.name),
              selected: ist,
              onSelected: (_) => onChanged(l.id),
              selectedColor: farbe.withValues(alpha: 0.3),
              backgroundColor: AppColors.card,
              labelStyle: TextStyle(
                color: ist ? farbe : AppColors.textSecondary,
                fontSize: 13,
              ),
              side: BorderSide(
                  color: ist ? farbe : AppColors.divider, width: 1),
              showCheckmark: false,
            );
          }).toList(),
        );
      },
    );
  }
}
