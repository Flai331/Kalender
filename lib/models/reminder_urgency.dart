/// Wie eindringlich eine Meldung sein soll.
///
/// **Je Stufe ein eigener Android-Kanal.** Die Wichtigkeit eines Kanals steht
/// ab seiner Anlage fest: Android ignoriert jede spaetere Aenderung, damit
/// keine App sich selbst lauter stellen kann. Wer hier umstellt, bekommt also
/// einen anderen Kanal — nicht denselben mit neuer Einstellung. Darum traegt
/// [id] den Kanalnamen mit (`abfahrt_dringend`), und darum bleiben die ids
/// stehen, auch wenn die Beschriftung sich einmal aendert.
///
/// Das letzte Wort hat ohnehin das Handy: wer einen Kanal in den
/// Android-Einstellungen leiser stellt, bleibt leiser.
enum ReminderUrgency {
  /// Steht nur in der Leiste. Kein Ton, kein Rutteln, kein Einblenden.
  still('still', 'Still', 'Nur in der Leiste — kein Ton'),

  /// Gibt einen Ton, blendet sich aber nicht ueber den Bildschirm.
  normal('normal', 'Normal', 'Ton, aber keine Einblendung'),

  /// Blendet sich ein und vibriert. Fuer alles, was man nicht verpassen will.
  dringend('dringend', 'Dringend', 'Ton, Vibration und Einblendung'),

  /// Wie ein Wecker: ueber die Alarm-Lautstaerke, die beim Stummschalten des
  /// Klingeltons nicht mitgeht.
  alarm('alarm', 'Wie ein Wecker', 'Weckerton über die Alarm-Lautstärke');

  const ReminderUrgency(this.id, this.label, this.beschreibung);

  /// Dauerhafte Kennung — steht in den Einstellungen und im Kanalnamen.
  final String id;

  /// Was in der Auswahl steht.
  final String label;

  /// Eine Zeile darunter: was die Stufe tatsaechlich tut.
  final String beschreibung;

  /// Aus der gespeicherten Kennung zurueck. Unbekanntes wird [normal] —
  /// eine kaputte Einstellung darf keine Meldung verschlucken.
  static ReminderUrgency fromId(String? id) {
    for (final u in values) {
      if (u.id == id) return u;
    }
    return normal;
  }
}
