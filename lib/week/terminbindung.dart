import '../models/calendar_event.dart';
import '../models/todo.dart';
import '../services/travel_service.dart';

/// Welche Termine ein To-do beherbergen duerfen.
///
/// Manches laesst sich nur **waehrend** eines Termins tun: die Abrechnung im
/// Dienst, der Anruf im Buero, das Einkaufen auf dem Heimweg. Dafuer tragen
/// To-dos zwei Bedingungen — eine Kategorie und einen Kalender. Beide sind
/// freiwillig, beide verengen.
///
/// Rein gerechnet: kein Bildschirm, keine Datenbank, keine Uhr.
class Terminbindung {
  /// Traegt dieses To-do ueberhaupt eine Bedingung?
  ///
  /// Ohne eine der beiden gibt es nichts zu suchen — ein To-do „im Termin"
  /// ohne jede Angabe passt nirgends, und das war auch vorher so.
  static bool gebunden(Todo todo) =>
      todo.requiredCategory != null || todo.requiredCalendarId != null;

  /// Gilt die Bindung fuer diesen Planungsmodus?
  static bool giltFuer(TodoContextMode modus) =>
      modus == TodoContextMode.categoryEvent ||
      modus == TodoContextMode.opportunistic;

  /// Soll die App diesem To-do von sich aus einen **ersten** Platz geben?
  ///
  /// Nur, wenn es ohnehin nur in einem bestimmten Termin erledigt werden
  /// kann: dann steht der naechste passende Termin fest, und das To-do muss
  /// nicht in der Leiste liegen bleiben, bis man es hinzieht. Bei allem
  /// anderen entscheidet man selbst, wann es drankommt.
  static bool brauchtErstenPlatz(Todo todo) =>
      giltFuer(todo.contextMode) && gebunden(todo);

  /// Darf [termin] dieses To-do beherbergen?
  ///
  /// [kategorie] und [kalenderId] sind die Bedingungen des To-dos; `null`
  /// heisst jeweils „gleichgueltig".
  static bool passt(
    CalendarEvent termin, {
    String? kategorie,
    String? kalenderId,
  }) {
    // Ohne Bedingung gibt es keinen Gastgeber. Sonst wuerde aus „nur im
    // Termin" ein „irgendwann".
    if (kategorie == null && kalenderId == null) return false;
    // Ein Ganztagstermin ist kein Zeitfenster, in das etwas hineinpasst.
    if (termin.isAllDay) return false;
    if (kategorie != null && termin.category != kategorie) return false;
    if (kalenderId != null &&
        TravelService.calendarIdOf(termin) != kalenderId) {
      return false;
    }
    // Ein Termin nur zur Kenntnis belegt keine Zeit — als Gastgeber taugt er
    // nur, wenn der Kalender ausdruecklich gewaehlt ist. Sonst landete ein
    // To-do „im Termin, Kategorie Arbeit" im Dienst eines anderen Menschen,
    // denn importierte Termine tragen alle die Kategorie Arbeit.
    if (termin.infoOnly && kalenderId == null) return false;
    return true;
  }

  /// Die Termine eines Tages, die [todo] beherbergen duerfen — in der
  /// Reihenfolge, in der sie hereinkommen.
  static List<CalendarEvent> gastgeber(
    List<CalendarEvent> termine,
    Todo todo,
  ) =>
      termine
          .where((e) => passt(e,
              kategorie: todo.requiredCategory,
              kalenderId: todo.requiredCalendarId))
          .toList();
}
