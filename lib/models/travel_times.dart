/// An- und Abfahrtszeit in Minuten.
///
/// Beide Seiten sind einzeln optional: `null` heisst „hier ist nichts
/// eingestellt, es gilt die naechst allgemeinere Vorgabe". Damit laesst sich
/// z. B. nur die Anfahrt eines Termins festlegen, waehrend die Abfahrt weiter
/// vom Kalender kommt. Ein gesetztes `0` ist dagegen eine Aussage: „hier
/// ausdruecklich keine Zeit", auch wenn der Kalender eine vorgibt.
class TravelTimes {
  final int? before;
  final int? after;

  const TravelTimes({this.before, this.after});

  static const TravelTimes none = TravelTimes();

  bool get isEmpty => before == null && after == null;

  TravelTimes copyWith({
    Object? before = _unset,
    Object? after = _unset,
  }) =>
      TravelTimes(
        before: before == _unset ? this.before : before as int?,
        after: after == _unset ? this.after : after as int?,
      );

  static const Object _unset = Object();

  Map<String, dynamic> toJson() => {'before': before, 'after': after};

  factory TravelTimes.fromJson(Map<String, dynamic> json) => TravelTimes(
        before: (json['before'] as num?)?.toInt(),
        after: (json['after'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is TravelTimes && other.before == before && other.after == after;

  @override
  int get hashCode => Object.hash(before, after);

  @override
  String toString() => 'TravelTimes(before: $before, after: $after)';
}
