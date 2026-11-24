import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/todo_liste.dart';
import 'local_service.dart';

const _uuid = Uuid();

/// Die Listen der To-dos und die Ordner, in denen sie stehen — wie bei
/// Microsoft To Do: Ordner enthalten Listen, Listen enthalten To-dos.
///
/// Gelesen wird oft (jede Karte will den Namen ihrer Liste), geschrieben
/// selten — darum haelt der Dienst die Listen im Speicher und laedt nur
/// einmal. [revision] meldet jede Aenderung, damit offene Bildschirme
/// nachziehen.
///
/// ## Die Standardliste
///
/// [standardId] steht fest und wird nie geloescht. Dort landet alles, was
/// keine Liste nennt — also alle To-dos, die es vor den Listen schon gab,
/// und alles aus einer alten Sicherung. So kann kein To-do unsichtbar
/// werden, weil seine Liste fehlt.
class ListenService {
  /// Die Kennung der Standardliste. Fest, nicht erraten: eine Sicherung von
  /// einem anderen Geraet muss dieselbe Liste treffen.
  static const String standardId = 'aufgaben';

  /// Die Standardliste, wie sie beim ersten Start angelegt wird.
  static const TodoListe standardVorgabe = TodoListe(
    id: standardId,
    name: 'Aufgaben',
    farbe: 0xFF448AFF,
  );

  static List<TodoListe> _items = const [];
  static bool _geladen = false;

  /// Zaehlt bei jeder Aenderung hoch — wie bei den Kategorien und den
  /// Vorlagen.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool get istGeladen => _geladen;

  /// Alle Listen in ihrer Reihenfolge. Die Standardliste ist dabei, sie
  /// steht wie jede andere in der Reihe.
  static List<TodoListe> get alle => List.unmodifiable(_items);

  static Future<List<TodoListe>> laden() async {
    if (_geladen) return _items;
    final gespeichert = await LocalService.getTodoListen();
    if (gespeichert.isEmpty) {
      _items = const [standardVorgabe];
      await LocalService.seedTodoListen(_items);
    } else {
      _items = _mitStandard(gespeichert);
    }
    _geladen = true;
    return _items;
  }

  /// Liest die Listen neu aus der Datenbank. Nach dem Einspielen einer
  /// Sicherung steht dort etwas anderes als im Speicher.
  static Future<void> neuLaden() async {
    _geladen = false;
    _items = const [];
    await laden();
    revision.value++;
  }

  @visibleForTesting
  static void resetForTesting() {
    _items = const [];
    _geladen = false;
  }

  // ── Nachsehen ─────────────────────────────────────────────────────────────

  static TodoListe? byId(String? id) {
    if (id == null) return null;
    for (final l in _items) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Die Liste, in der ein To-do wirklich steht.
  ///
  /// [roh] ist das Feld am To-do. Leer heisst Standardliste; eine Kennung,
  /// die es nicht mehr gibt, ebenfalls — ein To-do verschwindet nicht,
  /// bloss weil seine Liste geloescht wurde.
  static String echteListe(String? roh) =>
      (roh != null && byId(roh) != null) ? roh : standardId;

  /// Der sichtbare Name. Fuer eine Liste, die es nicht gibt, der Name der
  /// Standardliste — dort steht das To-do dann auch.
  static String nameOf(String? id) =>
      byId(echteListe(id))?.name ?? standardVorgabe.name;

  static int farbeOf(String? id) =>
      byId(echteListe(id))?.farbe ?? standardVorgabe.farbe;

  /// Die Ordner, in der Reihenfolge, in der ihre erste Liste steht.
  static List<String> get ordner {
    final raus = <String>[];
    for (final l in _items) {
      if (l.imOrdner && !raus.contains(l.ordner)) raus.add(l.ordner);
    }
    return raus;
  }

  /// Die Listen eines Ordners, in ihrer Reihenfolge.
  static List<TodoListe> imOrdner(String name) =>
      _items.where((l) => l.ordner == name).toList();

  /// Die Listen, die in keinem Ordner stehen.
  static List<TodoListe> get ohneOrdner =>
      _items.where((l) => !l.imOrdner).toList();

  // ── Aendern ───────────────────────────────────────────────────────────────

  static Future<void> _schreibe() async {
    _items = _mitStandard(_items);
    await LocalService.saveTodoListen(_items);
    revision.value++;
  }

  /// Legt eine Liste an und gibt sie zurueck.
  ///
  /// Doppelte Namen sind erlaubt: „Einkauf" im Ordner Privat und „Einkauf"
  /// im Ordner Arbeit sind zwei verschiedene Listen, und wer sie so nennen
  /// will, soll das duerfen.
  static Future<TodoListe> anlegen(
    String name, {
    String ordner = '',
    int farbe = 0xFF9E9E9E,
  }) async {
    final sauber = name.trim();
    final liste = TodoListe(
      id: _uuid.v4(),
      name: sauber.isEmpty ? 'Neue Liste' : sauber,
      ordner: ordner.trim(),
      farbe: farbe,
    );
    _items = [..._items, liste];
    await _schreibe();
    return liste;
  }

  /// Benennt eine Liste um. Falsch, wenn der Name leer ist.
  static Future<bool> umbenennen(String id, String name) async {
    final sauber = name.trim();
    if (sauber.isEmpty) return false;
    if (byId(id) == null) return false;
    _items = _items
        .map((l) => l.id == id ? l.copyWith(name: sauber) : l)
        .toList();
    await _schreibe();
    return true;
  }

  static Future<void> faerben(String id, int farbe) async {
    if (byId(id) == null) return;
    _items =
        _items.map((l) => l.id == id ? l.copyWith(farbe: farbe) : l).toList();
    await _schreibe();
  }

  /// Steckt eine Liste in einen Ordner. Leerer Name holt sie heraus.
  ///
  /// Hier entstehen Ordner: einen leeren Ordner gibt es nicht, weil der
  /// Ordner nur der Name an seinen Listen ist.
  static Future<void> inOrdner(String id, String ordner) async {
    if (byId(id) == null) return;
    final ziel = ordner.trim();
    _items = _items
        .map((l) => l.id == id ? l.copyWith(ordner: ziel) : l)
        .toList();
    await _schreibe();
  }

  /// Loescht eine Liste und haengt ihre To-dos in die Standardliste um.
  ///
  /// Die Standardliste selbst bleibt stehen — ohne sie haette das
  /// Umhaengen kein Ziel.
  static Future<bool> loeschen(String id) async {
    if (id == standardId) return false;
    if (byId(id) == null) return false;
    await LocalService.todosUmhaengen(id, null);
    _items = _items.where((l) => l.id != id).toList();
    await _schreibe();
    return true;
  }

  /// Verschiebt die Liste an [alt] auf die Stelle [neu].
  static Future<void> sortieren(int alt, int neu) async {
    if (alt < 0 || alt >= _items.length) return;
    final liste = List.of(_items);
    final l = liste.removeAt(alt);
    liste.insert(neu.clamp(0, liste.length), l);
    _items = liste;
    await _schreibe();
  }

  /// Benennt einen Ordner um — also den Ordnernamen an allen seinen
  /// Listen. Falsch, wenn der neue Name leer ist.
  static Future<bool> ordnerUmbenennen(String alt, String neu) async {
    final sauber = neu.trim();
    if (sauber.isEmpty || alt.isEmpty) return false;
    if (!ordner.contains(alt)) return false;
    _items = _items
        .map((l) => l.ordner == alt ? l.copyWith(ordner: sauber) : l)
        .toList();
    await _schreibe();
    return true;
  }

  /// Loest einen Ordner auf: seine Listen stehen danach fuer sich. Die
  /// Listen selbst bleiben, denn in ihnen stehen die To-dos.
  static Future<bool> ordnerAufloesen(String name) async {
    if (name.isEmpty || !ordner.contains(name)) return false;
    _items = _items
        .map((l) => l.ordner == name ? l.copyWith(ordner: '') : l)
        .toList();
    await _schreibe();
    return true;
  }

  // ── Intern ────────────────────────────────────────────────────────────────

  /// Sorgt dafuer, dass die Standardliste da ist und jede Kennung nur
  /// einmal vorkommt.
  ///
  /// Eine Sicherung kann von einer aelteren Fassung kommen oder von Hand
  /// bearbeitet sein; ohne Standardliste waeren alle To-dos ohne Liste
  /// heimatlos.
  static List<TodoListe> _mitStandard(List<TodoListe> roh) {
    final gesehen = <String>{};
    final raus = roh.where((l) => gesehen.add(l.id)).toList();
    if (!gesehen.contains(standardId)) {
      return [standardVorgabe, ...raus];
    }
    return raus;
  }
}
