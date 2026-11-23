import '../models/calendar_event.dart';
import '../models/todo.dart';

/// Ein belegter Abschnitt des Tages, in Minuten ab Mitternacht.
typedef Zeitblock = (int von, int bis);

/// Der Platz, den ein To-do bekommt.
typedef Nachholplatz = ({String id, int stunde, int minute});

/// Wohin die App legt, was liegengeblieben ist.
///
/// Rein gerechnet — ohne Bildschirm, ohne Datenbank, ohne Uhr. Die
/// Wochenansicht fragt nur noch nach dem Platz und schreibt ihn hin.
class Nachholen {
  /// Wie weit **nach** der aktuellen Uhrzeit das Nachgeholte anfaengt.
  ///
  /// Nicht auf die Minute genau, und nicht davor: ein Block, der schon
  /// angefangen hat, haengt hinter der Jetzt-Linie und sieht aus wie etwas
  /// Verpasstes. Was man noch vor sich hat, gehoert unter die Linie — fuenf
  /// Minuten Luft heisst „als Naechstes dran".
  static const int vorlauf = 5;

  /// Die frueheste Minute, auf die heute etwas gelegt wird.
  ///
  /// Nach hinten begrenzt: kurz vor Mitternacht gibt es kein „fuenf Minuten
  /// spaeter" mehr, und im Nirgendwo soll nichts landen.
  static int fruehestens(int jetztMinute) {
    const letzte = 24 * 60 - 1;
    final spaet = jetztMinute + vorlauf;
    return spaet > letzte ? letzte : spaet;
  }

  /// Welche Abschnitte des Tages wirklich belegt sind.
  ///
  /// Die Termine muessen **aufgeloest** hereinkommen
  /// ([TravelService.resolveAll]) und zum selben Tag gehoeren: die Anfahrt
  /// eines importierten Termins steht am Kalender, nicht am Termin.
  ///
  /// Draussen bleiben zwei Sorten:
  /// * **Nur zur Kenntnis.** Der Dienstplan eines anderen Menschen belegt
  ///   nicht die eigene Zeit — darueber darf ein To-do liegen. Ob ein
  ///   abonnierter Kalender zur Kenntnis steht oder als eigener Termin
  ///   zaehlt, steht je Kalender und je Termin in den Einstellungen.
  /// * **Ganztaegig.** Sonst waere der ganze Tag weg und nichts liesse sich
  ///   mehr nachholen.
  static List<Zeitblock> belegteZeiten(List<CalendarEvent> termine) => [
        for (final e in termine)
          if (!e.infoOnly && !e.isAllDay)
            (
              e.startTime.hour * 60 +
                  e.startTime.minute -
                  e.travelMinutesBefore,
              e.endTime.hour * 60 + e.endTime.minute + e.travelMinutesAfter,
            ),
      ];

  /// Schiebt [von] nach hinten, bis ein Block von [dauer] Minuten in keinen
  /// belegten Abschnitt mehr hineinragt.
  ///
  /// Wiederholt, nicht einmal: hinter dem einen Termin kann der naechste
  /// stehen, und wer nur einmal ausweicht, landet mitten im zweiten.
  static int hinterTermine(int von, int dauer, List<Zeitblock> belegt) {
    var pos = von;
    var nochmal = true;
    while (nochmal) {
      nochmal = false;
      for (final (anfang, ende) in belegt) {
        if (pos < ende && pos + dauer > anfang) {
          pos = ende;
          nochmal = true;
        }
      }
    }
    return pos;
  }

  /// Wo die liegengebliebenen To-dos heute anfangen.
  ///
  /// Der Reihe nach ab [jetztMinute] plus [vorlauf], eines hinter dem
  /// anderen, mit einem Bogen um die echten Termine. Die alte Uhrzeit zaehlt
  /// nicht mehr: dass etwas gestern um neun dran war, sagt nichts darueber,
  /// was heute um neun los ist.
  ///
  /// Gerechnet wird mit dem **ganzen** Block — Anfahrt, Dauer, Heimweg —,
  /// zurueckgegeben aber die Uhrzeit des To-dos selbst.
  static List<Nachholplatz> plan({
    required List<Todo> todos,
    required List<Zeitblock> belegt,
    required int jetztMinute,
  }) {
    var kante = fruehestens(jetztMinute);
    final plaetze = <Nachholplatz>[];
    for (final t in todos) {
      final dauer =
          t.travelMinutesBefore + t.estimatedMinutes + t.travelMinutesAfter;
      final anfang = hinterTermine(kante, dauer, belegt);
      // Ueber Mitternacht hinaus geht nicht: der Tag hat nur 24 Stunden, und
      // das To-do soll heute stehen, nicht im Nirgendwo.
      final start = (anfang + t.travelMinutesBefore).clamp(0, 24 * 60 - 1);
      plaetze.add((id: t.id, stunde: start ~/ 60, minute: start % 60));
      kante = anfang + dauer;
    }
    return plaetze;
  }
}
