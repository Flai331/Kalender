import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/category_service.dart';

/// Auswahl einer Kategorie. Eine Liste fuer die ganze App — frueher stand
/// dieselbe Reihe Knoepfe in drei Bildschirmen, jeder mit eigener
/// Beschriftung und eigenem Aussehen.
///
/// Zeigt die Kategorien des Benutzers. Traegt der bearbeitete Eintrag eine
/// Kategorie, die es nicht mehr gibt, wird sie trotzdem angezeigt (grau) —
/// sonst wuerde allein das Oeffnen des Bildschirms sie heimlich austauschen.
class CategoryPicker extends StatelessWidget {
  /// Schluessel der gewaehlten Kategorie, null fuer "keine".
  final String? selected;

  final ValueChanged<String?> onChanged;

  /// Wenn true, hebt ein Tipp auf die gewaehlte Kategorie die Auswahl wieder
  /// auf. Gedacht fuer Filter ("egal welche Kategorie").
  final bool allowNone;

  const CategoryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.allowNone = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CategoryService.revision,
      builder: (context, _, child) {
        final cats = CategoryService.all;
        final keys = [
          ...cats.map((c) => c.key),
          // Verwaiste Kategorie des Eintrags mit anbieten.
          if (selected != null &&
              selected!.isNotEmpty &&
              !CategoryService.exists(selected))
            selected!,
        ];

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: keys.map((key) {
            final isSelected = selected == key;
            final color = CategoryService.colorOf(key);
            return ChoiceChip(
              label: Text(CategoryService.labelOf(key)),
              selected: isSelected,
              onSelected: (_) =>
                  onChanged(isSelected && allowNone ? null : key),
              selectedColor: color.withValues(alpha: 0.3),
              backgroundColor: AppColors.card,
              labelStyle: TextStyle(
                color: isSelected ? color : AppColors.textSecondary,
                fontSize: 13,
              ),
              side: BorderSide(
                  color: isSelected ? color : AppColors.divider, width: 1),
              showCheckmark: false,
            );
          }).toList(),
        );
      },
    );
  }
}
