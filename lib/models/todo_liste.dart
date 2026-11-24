import 'dart:convert';

/// Eine Liste, in der To-dos stehen: „Einkauf", „Haushalt", „Dienst".
///
/// Wie bei Microsoft To Do gehoert ein To-do in genau eine Liste, und
/// mehrere Listen koennen in einem Ordner liegen.
///
/// ## Warum der Ordner nur ein Name ist
///
/// [ordner] ist der Name des Ordners, nicht die Kennung eines eigenen
/// Eintrags — genauso macht es `Place.group` bei den Orten. Ein Ordner ist
/// damit nichts, was fuer sich besteht: er ist da, solange eine Liste ihn
/// nennt. Das spart eine zweite Tabelle und eine zweite Verwaltung.
///
/// Der Preis: Umbenennen fasst alle Listen des Ordners an, und der letzte
/// Ordner verschwindet, sobald seine letzte Liste herausgezogen wird. Fuer
/// eine Handvoll Ordner auf einem Telefon ist das der bessere Tausch.
///
/// Die **Reihenfolge** steckt nicht im Eintrag, sondern in der Liste selbst
/// — wie bei den Kategorien. Verschieben heisst umsortieren, nicht eine
/// Zahl hochzaehlen.
class TodoListe {
  final String id;
  final String name;

  /// Der Ordner, in dem die Liste steht. Leer heisst: steht fuer sich.
  final String ordner;

  /// Farbwert wie bei den Kategorien (`0xFF...`).
  final int farbe;

  const TodoListe({
    required this.id,
    required this.name,
    this.ordner = '',
    required this.farbe,
  });

  bool get imOrdner => ordner.isNotEmpty;

  TodoListe copyWith({
    String? id,
    String? name,
    String? ordner,
    int? farbe,
  }) =>
      TodoListe(
        id: id ?? this.id,
        name: name ?? this.name,
        ordner: ordner ?? this.ordner,
        farbe: farbe ?? this.farbe,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ordner': ordner,
        'farbe': farbe,
      };

  static TodoListe? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.isEmpty) return null;
    return TodoListe(
      id: id,
      name: name,
      ordner: json['ordner'] as String? ?? '',
      farbe: (json['farbe'] as num?)?.toInt() ?? 0xFF9E9E9E,
    );
  }

  static List<TodoListe> listFromJson(String raw) {
    final daten = jsonDecode(raw);
    if (daten is! List) return [];
    final raus = <TodoListe>[];
    for (final e in daten) {
      if (e is! Map) continue;
      final l = TodoListe.fromJson(Map<String, dynamic>.from(e));
      if (l != null) raus.add(l);
    }
    return raus;
  }

  static String listToJson(List<TodoListe> listen) =>
      jsonEncode(listen.map((l) => l.toJson()).toList());

  @override
  bool operator ==(Object other) =>
      other is TodoListe &&
      other.id == id &&
      other.name == name &&
      other.ordner == ordner &&
      other.farbe == farbe;

  @override
  int get hashCode => Object.hash(id, name, ordner, farbe);

  @override
  String toString() => ordner.isEmpty ? name : '$ordner/$name';
}
