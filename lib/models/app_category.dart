import 'package:flutter/material.dart';

/// Eine Kategorie, wie der Benutzer sie selbst anlegt und benennt.
///
/// [key] ist die Kennung, die in den Daten steht — in `Todo.category`,
/// `CalendarEvent.category` und `AnnualEvent.category`. Sie bleibt beim
/// Umbenennen unveraendert; andernfalls verloeren alle bestehenden Eintraege
/// ihre Kategorie. Sichtbar ist immer nur [label].
class AppCategory {
  final String key;
  final String label;
  final int colorValue;

  const AppCategory({
    required this.key,
    required this.label,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  AppCategory copyWith({String? label, int? colorValue}) => AppCategory(
        key: key,
        label: label ?? this.label,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'color': colorValue,
      };

  /// Gibt null zurueck, wenn der Eintrag unbrauchbar ist. Eine kaputte
  /// Einstellung soll einzelne Kategorien kosten, nicht den Start der App.
  static AppCategory? fromJson(Map<String, dynamic> json) {
    final key = (json['key'] as String?)?.trim();
    if (key == null || key.isEmpty) return null;
    final label = (json['label'] as String?)?.trim();
    return AppCategory(
      key: key,
      label: (label == null || label.isEmpty) ? key : label,
      colorValue: (json['color'] as num?)?.toInt() ?? 0xFF9E9E9E,
    );
  }

  /// Die ganze Liste als ein JSON-Objekt.
  ///
  /// Ein Objekt mit 'items' und nicht ein nacktes Array: so kann spaeter ein
  /// Feld dazukommen, ohne dass das Gespeicherte unlesbar wird.
  static Map<String, dynamic> listToJson(List<AppCategory> items) =>
      {'items': items.map((c) => c.toJson()).toList()};

  /// Liest, was [listToJson] geschrieben hat. Gibt null zurueck, wenn der
  /// Inhalt keine Liste ist — "nichts gespeichert" ist dann etwas anderes als
  /// "leere Liste", und nur so kann der Aufrufer auf die Vorgaben
  /// zurueckfallen. Unbrauchbare Eintraege werden einzeln uebersprungen.
  static List<AppCategory>? listFromJson(dynamic decoded) {
    if (decoded is! Map) return null;
    final raw = decoded['items'];
    if (raw is! List) return null;
    final out = <AppCategory>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final c = fromJson(Map<String, dynamic>.from(e));
      if (c != null) out.add(c);
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is AppCategory &&
      other.key == key &&
      other.label == label &&
      other.colorValue == colorValue;

  @override
  int get hashCode => Object.hash(key, label, colorValue);

  @override
  String toString() => 'AppCategory($key, $label, '
      '0x${colorValue.toRadixString(16).padLeft(8, '0')})';
}
