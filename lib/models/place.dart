import 'dart:convert';
import 'dart:math' as math;

/// Ein Öffnungsfenster an einem Wochentag, in Minuten ab Mitternacht.
///
/// [toMinute] darf über 1440 hinausgehen: ein Studio, das bis 1 Uhr nachts
/// offen hat, steht als 1500 am Vortag — nicht als zweiter Eintrag am
/// Folgetag. Sonst ginge die Nacht von Sonntag auf Montag verloren.
class OpeningHours {
  /// 1 = Montag … 7 = Sonntag, wie `DateTime.weekday`.
  final int weekday;
  final int fromMinute;
  final int toMinute;

  const OpeningHours({
    required this.weekday,
    required this.fromMinute,
    required this.toMinute,
  });

  bool get isValid =>
      weekday >= 1 && weekday <= 7 && fromMinute >= 0 && toMinute > fromMinute;

  OpeningHours copyWith({int? weekday, int? fromMinute, int? toMinute}) =>
      OpeningHours(
        weekday: weekday ?? this.weekday,
        fromMinute: fromMinute ?? this.fromMinute,
        toMinute: toMinute ?? this.toMinute,
      );

  Map<String, dynamic> toJson() =>
      {'weekday': weekday, 'from': fromMinute, 'to': toMinute};

  factory OpeningHours.fromJson(Map<String, dynamic> json) => OpeningHours(
        weekday: json['weekday'] as int,
        fromMinute: json['from'] as int,
        toMinute: json['to'] as int,
      );

  static String minuteToText(int minute) {
    // Punkt Mitternacht ist als Schlusszeit gemeint: "bis 24:00" liest sich
    // richtig, "bis 00:00" sieht nach einem Fehler aus.
    if (minute == 1440) return '24:00';
    final h = (minute ~/ 60) % 24;
    final m = minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String get text =>
      '${minuteToText(fromMinute)}–${minuteToText(toMinute)}'
      '${toMinute >= 1440 ? ' (nachts)' : ''}';

  @override
  bool operator ==(Object other) =>
      other is OpeningHours &&
      other.weekday == weekday &&
      other.fromMinute == fromMinute &&
      other.toMinute == toMinute;

  @override
  int get hashCode => Object.hash(weekday, fromMinute, toMinute);

  @override
  String toString() => '$weekday: $text';
}

/// Ein Zeitraum, in dem ein Ort offen hat.
class OpenWindow {
  final DateTime from;
  final DateTime to;

  const OpenWindow(this.from, this.to);

  bool contains(DateTime t) => !t.isBefore(from) && t.isBefore(to);

  @override
  String toString() => '$from – $to';
}

/// Ein Ort mit Öffnungszeiten: ein Fitnessstudio, ein Laden, eine Praxis.
///
/// [group] fasst zusammen, was gegeneinander antritt ("Fitnessstudio"):
/// Vorschläge werden immer innerhalb einer Gruppe gesucht. [rank] ist die
/// Rangliste innerhalb dieser Gruppe — kleiner heisst lieber.
class Place {
  final String id;
  final String name;
  final String group;
  final String address;

  /// Koordinaten, falls bekannt. Ohne sie zählt nur die Rangliste.
  final double? latitude;
  final double? longitude;

  final int rank;
  final List<OpeningHours> hours;
  final String note;

  const Place({
    required this.id,
    required this.name,
    required this.group,
    this.address = '',
    this.latitude,
    this.longitude,
    this.rank = 0,
    this.hours = const [],
    this.note = '',
  });

  bool get hasPosition => latitude != null && longitude != null;

  /// Sind überhaupt brauchbare Öffnungszeiten eingetragen?
  ///
  /// Wenn nicht, gilt der Ort als immer offen. Sonst waere ein gerade
  /// angelegtes Studio, dessen Zeiten man noch nicht eingetippt hat, für
  /// immer unsichtbar — und die App sagte "keiner offen", obwohl drei Orte
  /// in der Liste stehen.
  bool get hasHours => hours.any((h) => h.isValid);

  Place copyWith({
    String? id,
    String? name,
    String? group,
    String? address,
    double? latitude,
    double? longitude,
    bool clearPosition = false,
    int? rank,
    List<OpeningHours>? hours,
    String? note,
  }) =>
      Place(
        id: id ?? this.id,
        name: name ?? this.name,
        group: group ?? this.group,
        address: address ?? this.address,
        latitude: clearPosition ? null : (latitude ?? this.latitude),
        longitude: clearPosition ? null : (longitude ?? this.longitude),
        rank: rank ?? this.rank,
        hours: hours ?? this.hours,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'group': group,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'rank': rank,
        'hours': hours.map((h) => h.toJson()).toList(),
        'note': note,
      };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String,
        name: json['name'] as String,
        group: json['group'] as String? ?? '',
        address: json['address'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        rank: json['rank'] as int? ?? 0,
        hours: (json['hours'] as List<dynamic>?)
                ?.map((e) => OpeningHours.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        note: json['note'] as String? ?? '',
      );

  static List<Place> listFromJson(String raw) =>
      (jsonDecode(raw) as List)
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList();

  static String listToJson(List<Place> places) =>
      jsonEncode(places.map((p) => p.toJson()).toList());

  // ── Öffnungszeiten ────────────────────────────────────────────────────

  /// Die Öffnungsfenster, die sich mit [from] bis [to] überschneiden,
  /// zusammengefasst: zwei Fenster, die aneinander stossen, werden eins.
  ///
  /// Geht einen Tag vor und zurueck, damit ein Fenster ueber Mitternacht
  /// ("bis 1 Uhr") nicht verloren geht.
  List<OpenWindow> openWindows(DateTime from, DateTime to) {
    final roh = <OpenWindow>[];
    var tag = DateTime(from.year, from.month, from.day - 1);
    final letzter = DateTime(to.year, to.month, to.day + 1);

    while (!tag.isAfter(letzter)) {
      for (final h in hours) {
        if (h.weekday != tag.weekday || !h.isValid) continue;
        roh.add(OpenWindow(_at(tag, h.fromMinute), _at(tag, h.toMinute)));
      }
      tag = DateTime(tag.year, tag.month, tag.day + 1);
    }

    roh.sort((a, b) => a.from.compareTo(b.from));
    final zusammen = <OpenWindow>[];
    for (final f in roh) {
      if (zusammen.isNotEmpty && !f.from.isAfter(zusammen.last.to)) {
        final letzte = zusammen.removeLast();
        zusammen.add(OpenWindow(
            letzte.from, f.to.isAfter(letzte.to) ? f.to : letzte.to));
      } else {
        zusammen.add(f);
      }
    }

    return zusammen
        .where((f) => f.from.isBefore(to) && f.to.isAfter(from))
        .toList();
  }

  /// Hat der Ort zu diesem Zeitpunkt offen?
  bool isOpenAt(DateTime t) =>
      !hasHours ||
      openWindows(t, t.add(const Duration(minutes: 1)))
          .any((f) => f.contains(t));

  /// Hat der Ort den **ganzen** Zeitraum über offen? Darum geht es beim
  /// Termin: halb offen heisst, man steht vor verschlossener Tuer.
  bool isOpenDuring(DateTime from, DateTime to) {
    if (!hasHours) return true;
    if (!to.isAfter(from)) return isOpenAt(from);
    return openWindows(from, to)
        .any((f) => !f.from.isAfter(from) && !f.to.isBefore(to));
  }

  /// Wann wird nach [t] geschlossen? Null, wenn gerade zu ist.
  DateTime? closingAfter(DateTime t) {
    for (final f in openWindows(t, t.add(const Duration(minutes: 1)))) {
      if (f.contains(t)) return f.to;
    }
    return null;
  }

  /// Das nächste Öffnen ab [t]. Sucht bis zu [tage] Tage voraus.
  DateTime? nextOpening(DateTime t, {int tage = 8}) {
    final fenster =
        openWindows(t, DateTime(t.year, t.month, t.day + tage));
    for (final f in fenster) {
      if (!f.from.isBefore(t)) return f.from;
    }
    return null;
  }

  static DateTime _at(DateTime tag, int minute) =>
      // Ueber den Minuten-Ueberlauf statt mit Duration: an der Nacht der
      // Zeitumstellung hat ein Tag 23 oder 25 Stunden, eine addierte Dauer
      // landet dann auf der falschen Uhrzeit.
      DateTime(tag.year, tag.month, tag.day, 0, minute);

  @override
  bool operator ==(Object other) {
    if (other is! Place) return false;
    if (other.hours.length != hours.length) return false;
    for (var i = 0; i < hours.length; i++) {
      if (other.hours[i] != hours[i]) return false;
    }
    return other.id == id &&
        other.name == name &&
        other.group == group &&
        other.address == address &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.rank == rank &&
        other.note == note;
  }

  @override
  int get hashCode => Object.hash(id, name, group, address, latitude,
      longitude, rank, note, Object.hashAll(hours));

  @override
  String toString() => '$name ($group)';
}

/// Luftlinie in Kilometern zwischen zwei Punkten (Haversine).
///
/// Luftlinie, nicht Fahrstrecke: ohne Routendienst ist das die ehrlichste
/// Zahl, und zum Sortieren von drei Studios in einer Stadt reicht sie.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const erdradius = 6371.0;
  double rad(double grad) => grad * math.pi / 180.0;

  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return erdradius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
