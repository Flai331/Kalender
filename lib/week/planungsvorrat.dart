import '../models/calendar_event.dart';

/// Die Termine, mit denen die Planung rechnet — nach Tagen sortiert.
///
/// Die Wochenansicht haelt nur, was sie **zeigt**. Die Suche nach einem Platz
/// geht aber bis zu 30 Tage voraus: ohne eigenen Vorrat sah sie hinter dem
/// sichtbaren Zeitraum nur leere Tage, hielt den naechsten Dienst fuer nicht
/// vorhanden und meldete „kein Platz" — oder legte ein To-do mitten in einen
/// Termin, von dem sie nichts wusste.
///
/// Reine Rechnung: wer die Termine beschafft, steht woanders.
class Planungsvorrat {
  final Map<int, List<CalendarEvent>> _mitZeit;
  final Map<int, List<CalendarEvent>> _ganztags;

  const Planungsvorrat._(this._mitZeit, this._ganztags);

  static const Planungsvorrat leer = Planungsvorrat._({}, {});

  static int _tag(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// Sortiert [termine] nach Tagen ein. Erwartet sie **aufgeloest**
  /// (`TravelService.resolveAll`) — die Anfahrt eines importierten Termins
  /// steht am Kalender, nicht am Termin.
  factory Planungsvorrat.aus(List<CalendarEvent> termine) {
    final mitZeit = <int, List<CalendarEvent>>{};
    final ganztags = <int, List<CalendarEvent>>{};
    for (final e in termine) {
      final topf = e.isAllDay ? ganztags : mitZeit;
      topf.putIfAbsent(_tag(e.startTime), () => []).add(e);
    }
    for (final liste in mitZeit.values) {
      liste.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return Planungsvorrat._(mitZeit, ganztags);
  }

  bool get istLeer => _mitZeit.isEmpty && _ganztags.isEmpty;

  /// Die Termine mit Uhrzeit, die an [tag] **anfangen**, in zeitlicher
  /// Reihenfolge.
  ///
  /// [mitNurInfo] nur fuer die Suche nach einem Gastgeber: ein Termin nur zur
  /// Kenntnis belegt keine Zeit, kann ein gebundenes To-do aber beherbergen.
  List<CalendarEvent> amTag(DateTime tag, {bool mitNurInfo = false}) {
    final liste = _mitZeit[_tag(tag)] ?? const <CalendarEvent>[];
    if (mitNurInfo) return liste;
    return liste.where((e) => !e.infoOnly).toList();
  }

  /// Sperrt ein Ganztagstermin diesen Tag? Nur die Kategorien aus
  /// [kategorien] sperren (Urlaub zum Beispiel), und nie einer, der nur zur
  /// Kenntnis dasteht — ein fremder Urlaub ist nicht der eigene.
  bool ganztagsGesperrt(DateTime tag, List<String> kategorien) =>
      (_ganztags[_tag(tag)] ?? const <CalendarEvent>[])
          .any((e) => !e.infoOnly && kategorien.contains(e.category));
}
