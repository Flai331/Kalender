import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_category.dart';
import 'local_service.dart';

/// Die Kategorien der App — welche es gibt, wie sie heissen, welche Farbe sie
/// haben. Frueher stand diese Liste viermal im Code, auf Englisch und fest
/// verdrahtet; hier steht sie einmal und gehoert dem Benutzer.
///
/// Gespeichert wird in der lokalen Datenbank, wie Termine und Todos — eine
/// Zeile je Benutzer mit der ganzen Liste, denn die Reihenfolge gehoert zur
/// Liste. Damit steckt sie auch in der Sicherung. Die Daten selbst (Todos,
/// Termine, Jahres-Events) tragen nur den Schluessel; Name und Farbe kommen
/// von hier.
class CategoryService {
  /// Nur noch fuer die einmalige Uebernahme: vor dem Umzug in die Datenbank
  /// stand die Liste unter diesem Schluessel in den Geraete-Einstellungen.
  static const String _legacyStorageKey = 'app_categories';

  /// Farbe fuer einen Schluessel, den es nicht mehr gibt. Bewusst neutral:
  /// so sieht man, dass die Kategorie fehlt, statt sie mit einer fremden zu
  /// verwechseln.
  static const int unknownColorValue = 0xFF9E9E9E;

  /// Die mitgelieferten Kategorien. Die Schluessel sind dieselben wie bisher
  /// im Code ('personal', 'work', ...), damit bestehende Termine und Todos
  /// ihre Kategorie behalten. Neu sind nur die deutschen Namen.
  static const List<AppCategory> defaults = [
    AppCategory(key: 'personal', label: 'Persönlich', colorValue: 0xFFFF6D00),
    AppCategory(key: 'work', label: 'Arbeit', colorValue: 0xFF448AFF),
    AppCategory(key: 'sport', label: 'Sport', colorValue: 0xFF69F0AE),
    AppCategory(key: 'vacation', label: 'Urlaub', colorValue: 0xFFFFD740),
  ];

  /// Auswahl fuer den Farbwaehler.
  static const List<int> palette = [
    0xFFFF6D00, // Orange
    0xFF448AFF, // Blau
    0xFF69F0AE, // Gruen
    0xFFFFD740, // Gelb
    0xFFFF5252, // Rot
    0xFF6C63FF, // Violett
    0xFF00BCD4, // Tuerkis
    0xFFE040FB, // Magenta
    0xFF8D6E63, // Braun
    0xFF9E9E9E, // Grau
  ];

  static List<AppCategory> _items = List.of(defaults);
  static bool _loaded = false;

  /// Zaehlt bei jeder Aenderung hoch. Offene Bildschirme haengen sich daran,
  /// damit eine umbenannte Kategorie sofort ueberall anders heisst.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool get isLoaded => _loaded;

  static List<AppCategory> get all => List.unmodifiable(_items);

  static List<String> get keys => _items.map((c) => c.key).toList();

  /// Die Kategorie, auf die zurueckgefallen wird, wenn keine angegeben ist.
  static String get fallbackKey =>
      _items.isEmpty ? 'personal' : _items.first.key;

  /// Reihenfolge der Quellen: lokale Datenbank, dann die alte Liste aus den
  /// Geraete-Einstellungen, dann die Vorgaben.
  static Future<void> load() async {
    _items = await _loadItems();
    _loaded = true;
    revision.value++;
  }

  static Future<List<AppCategory>> _loadItems() async {
    final List<AppCategory>? stored;
    try {
      stored = await LocalService.getCategories();
    } catch (_) {
      // Ohne lokale Datenbank bleibt es bei den Vorgaben, statt dass der
      // Start scheitert.
      return List.of(defaults);
    }
    if (stored != null && stored.isNotEmpty) return _dedupe(stored);

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyStorageKey);
    if (legacy != null && legacy.isNotEmpty) {
      final items = _decode(legacy);
      await LocalService.saveCategories(items);
      await prefs.remove(_legacyStorageKey);
      return items;
    }

    // Nichts gespeichert: die Vorgaben werden festgeschrieben.
    final items = List.of(defaults);
    await LocalService.seedCategories(items);
    return items;
  }

  static AppCategory? byKey(String? key) {
    if (key == null) return null;
    for (final c in _items) {
      if (c.key == key) return c;
    }
    return null;
  }

  static bool exists(String? key) => byKey(key) != null;

  /// Der sichtbare Name. Fuer einen Schluessel, den es nicht mehr gibt, der
  /// Schluessel selbst — besser etwas Unpassendes als gar nichts.
  static String labelOf(String? key) =>
      byKey(key)?.label ?? (key == null || key.isEmpty ? '—' : key);

  static int colorValueOf(String? key) =>
      byKey(key)?.colorValue ?? unknownColorValue;

  static Color colorOf(String? key) => Color(colorValueOf(key));

  // ── Aendern ───────────────────────────────────────────────────────────────

  static Future<void> _persist() async {
    await LocalService.saveCategories(_items);
    revision.value++;
  }

  /// Legt eine Kategorie an und gibt sie zurueck. Der Schluessel wird aus dem
  /// Namen gebildet und bleibt danach fest, auch wenn der Name sich aendert.
  static Future<AppCategory> add(String label, int colorValue) async {
    final name = label.trim();
    final cat = AppCategory(
      key: _freeKey(name),
      label: name.isEmpty ? 'Neue Kategorie' : name,
      colorValue: colorValue,
    );
    _items = [..._items, cat];
    await _persist();
    return cat;
  }

  static Future<void> update(String key,
      {String? label, int? colorValue}) async {
    final name = label?.trim();
    _items = _items
        .map((c) => c.key == key
            ? c.copyWith(
                label: (name == null || name.isEmpty) ? null : name,
                colorValue: colorValue)
            : c)
        .toList();
    await _persist();
  }

  /// Entfernt eine Kategorie. Die letzte bleibt stehen: eine App ohne jede
  /// Kategorie haette keine Auswahl mehr anzubieten.
  static Future<bool> remove(String key) async {
    if (_items.length <= 1) return false;
    final rest = _items.where((c) => c.key != key).toList();
    if (rest.length == _items.length) return false;
    _items = rest;
    await _persist();
    return true;
  }

  static Future<void> move(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    final list = List.of(_items);
    final cat = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), cat);
    _items = list;
    await _persist();
  }

  // ── Intern ────────────────────────────────────────────────────────────────

  /// Liest das alte Format aus den Geraete-Einstellungen: ein nacktes Array.
  static List<AppCategory> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return List.of(defaults);
    try {
      final data = jsonDecode(raw);
      if (data is! List) return List.of(defaults);
      final out = <AppCategory>[];
      for (final entry in data) {
        if (entry is! Map) continue;
        final cat = AppCategory.fromJson(Map<String, dynamic>.from(entry));
        if (cat != null) out.add(cat);
      }
      final unique = _dedupe(out);
      return unique.isEmpty ? List.of(defaults) : unique;
    } catch (_) {
      // Unlesbares Gespeichertes darf den Start nicht blockieren.
      return List.of(defaults);
    }
  }

  /// Ein Schluessel darf nur einmal vorkommen — sonst zeigt die Auswahl
  /// denselben Eintrag zweimal und labelOf waere nicht eindeutig.
  static List<AppCategory> _dedupe(List<AppCategory> items) {
    final seen = <String>{};
    return items.where((c) => seen.add(c.key)).toList();
  }

  /// Bildet aus dem Namen einen Schluessel, der noch frei ist.
  static String _freeKey(String label) {
    final base = slugify(label);
    if (!exists(base)) return base;
    for (var i = 2; i < 1000; i++) {
      final candidate = '${base}_$i';
      if (!exists(candidate)) return candidate;
    }
    return '${base}_${DateTime.now().millisecondsSinceEpoch}';
  }

  static final RegExp _plain = RegExp(r'[a-z0-9]');

  @visibleForTesting
  static String slugify(String label) {
    final lower = label.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == 'ä') {
        buffer.write('ae');
      } else if (ch == 'ö') {
        buffer.write('oe');
      } else if (ch == 'ü') {
        buffer.write('ue');
      } else if (ch == 'ß') {
        buffer.write('ss');
      } else if (_plain.hasMatch(ch)) {
        buffer.write(ch);
      } else {
        buffer.write('_');
      }
    }
    final slug = buffer.toString().replaceAll(RegExp(r'_+'), '_');
    final trimmed = slug.replaceAll(RegExp(r'^_+|_+$'), '');
    return trimmed.isEmpty ? 'kategorie' : trimmed;
  }

  @visibleForTesting
  static void resetForTesting() {
    _items = List.of(defaults);
    _loaded = false;
    revision.value = 0;
  }
}
