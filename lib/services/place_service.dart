import 'package:uuid/uuid.dart';

import '../models/place.dart';
import 'local_service.dart';

const _uuid = Uuid();

/// Ein Ort mit allem, was fuer die Entscheidung zaehlt: offen oder nicht,
/// wie weit weg, wann zu.
class PlaceSuggestion {
  final Place place;

  /// Hat den **ganzen** Zeitraum ueber offen.
  final bool open;

  /// Hat wenigstens zum Beginn des Termins offen, schliesst aber vorher.
  /// Das ist der Fall „kann hin, muss frueher raus" — der ist etwas
  /// anderes als zu, und soll nicht als zu dastehen.
  final bool openAtStart;

  /// Luftlinie in km, oder null — ohne Koordinaten oder ohne eigenen
  /// Standort gibt es keine Entfernung, und dann wird auch keine erfunden.
  final double? distanceKm;

  /// Wann an diesem Termin geschlossen wird.
  final DateTime? closesAt;

  /// Wann als naechstes geoeffnet wird, wenn zum Termin zu ist.
  final DateTime? nextOpening;

  const PlaceSuggestion({
    required this.place,
    required this.open,
    this.openAtStart = false,
    this.distanceKm,
    this.closesAt,
    this.nextOpening,
  });

  /// Offen beim Start, aber nicht bis zum Schluss.
  bool get closesDuring => !open && openAtStart;

  String get distanceText => distanceKm == null
      ? ''
      : distanceKm! < 1
          ? '${(distanceKm! * 1000).round()} m'
          : '${distanceKm!.toStringAsFixed(1)} km';

  @override
  String toString() => '${place.name}${open ? "" : " (zu)"}';
}

class PlaceService {
  // ── Speichern ────────────────────────────────────────────────────────

  static Future<List<Place>> all() => LocalService.getPlaces();

  /// Alle Orte einer Gruppe, in der Reihenfolge der Rangliste.
  static Future<List<Place>> inGroup(String group) async {
    final orte = (await all()).where((p) => p.group == group).toList();
    orte.sort(_nachRang);
    return orte;
  }

  /// Die Gruppen, die es gibt — alphabetisch, ohne Dopplungen.
  static Future<List<String>> groups() async {
    final namen = (await all()).map((p) => p.group).toSet().toList();
    namen.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return namen;
  }

  /// Legt einen Ort an. Er landet am Ende der Rangliste seiner Gruppe.
  static Future<Place> add({
    required String name,
    required String group,
    String address = '',
  }) async {
    final orte = await all();
    final letzterRang = orte
        .where((p) => p.group == group)
        .fold<int>(-1, (max, p) => p.rank > max ? p.rank : max);
    final neu = Place(
      id: _uuid.v4(),
      name: name.trim(),
      group: group.trim(),
      address: address.trim(),
      rank: letzterRang + 1,
    );
    await LocalService.savePlaces([...orte, neu]);
    return neu;
  }

  static Future<void> save(Place place) async {
    final orte = await all();
    final index = orte.indexWhere((p) => p.id == place.id);
    if (index < 0) {
      await LocalService.savePlaces([...orte, place]);
      return;
    }
    orte[index] = place;
    await LocalService.savePlaces(orte);
  }

  static Future<void> remove(String id) async {
    final orte = await all();
    orte.removeWhere((p) => p.id == id);
    await LocalService.savePlaces(_rangLueckenSchliessen(orte));
  }

  /// Setzt die Rangliste einer Gruppe neu — [idsInReihenfolge] ist die
  /// Liste, wie sie nach dem Ziehen dasteht.
  static Future<void> reorder(
      String group, List<String> idsInReihenfolge) async {
    final orte = await all();
    final neu = orte.map((p) {
      if (p.group != group) return p;
      final platz = idsInReihenfolge.indexOf(p.id);
      return platz < 0 ? p : p.copyWith(rank: platz);
    }).toList();
    await LocalService.savePlaces(neu);
  }

  // ── Vorschlagen ──────────────────────────────────────────────────────

  /// Welcher Ort der Gruppe passt zu diesem Termin?
  ///
  /// Reihenfolge: erst die, die den ganzen Zeitraum ueber offen haben, und
  /// darunter die Rangliste. Die Entfernung steht nur daneben — sie sortiert
  /// nicht, sie informiert. Wer heute lieber das naehere nimmt, sieht es und
  /// entscheidet selbst.
  ///
  /// [places] kann uebergeben werden, damit die Logik ohne Datenbank
  /// pruefbar ist.
  static Future<List<PlaceSuggestion>> suggest({
    required String group,
    required DateTime from,
    required DateTime to,
    double? myLatitude,
    double? myLongitude,
    List<Place>? places,
  }) async {
    final orte = (places ?? await all()).where((p) => p.group == group);
    final habeStandort = myLatitude != null && myLongitude != null;

    final liste = orte.map((p) {
      final offen = p.isOpenDuring(from, to);
      final amAnfang = offen || p.isOpenAt(from);
      return PlaceSuggestion(
        place: p,
        open: offen,
        openAtStart: amAnfang,
        distanceKm: habeStandort && p.hasPosition
            ? distanceKm(myLatitude, myLongitude, p.latitude!, p.longitude!)
            : null,
        closesAt: amAnfang ? p.closingAfter(from) : null,
        nextOpening: amAnfang ? null : p.nextOpening(from),
      );
    }).toList();

    liste.sort((a, b) {
      if (a.open != b.open) return a.open ? -1 : 1;
      // Unter den nicht ganz offenen zuerst die, bei denen man wenigstens
      // anfangen kann.
      if (a.openAtStart != b.openAtStart) return a.openAtStart ? -1 : 1;
      final rang = _nachRang(a.place, b.place);
      if (rang != 0) return rang;
      // Gleicher Rang kommt vor, wenn Orte von Hand angelegt wurden.
      final da = a.distanceKm, db = b.distanceKm;
      if (da != null && db != null && da != db) return da.compareTo(db);
      return a.place.name.toLowerCase().compareTo(b.place.name.toLowerCase());
    });
    return liste;
  }

  /// Der eine Ort, den die App vorschlaegt — oder null, wenn in der Gruppe
  /// zu dieser Zeit keiner offen hat.
  static Future<PlaceSuggestion?> best({
    required String group,
    required DateTime from,
    required DateTime to,
    double? myLatitude,
    double? myLongitude,
    List<Place>? places,
  }) async {
    final liste = await suggest(
      group: group,
      from: from,
      to: to,
      myLatitude: myLatitude,
      myLongitude: myLongitude,
      places: places,
    );
    if (liste.isEmpty || !liste.first.open) return null;
    return liste.first;
  }

  static int _nachRang(Place a, Place b) {
    final r = a.rank.compareTo(b.rank);
    return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  /// Nach dem Loeschen sollen die Raenge wieder 0,1,2 … sein.
  static List<Place> _rangLueckenSchliessen(List<Place> orte) {
    final nachGruppe = <String, List<Place>>{};
    for (final p in orte) {
      nachGruppe.putIfAbsent(p.group, () => []).add(p);
    }
    final out = <Place>[];
    for (final gruppe in nachGruppe.values) {
      gruppe.sort(_nachRang);
      for (var i = 0; i < gruppe.length; i++) {
        out.add(gruppe[i].copyWith(rank: i));
      }
    }
    return out;
  }
}
