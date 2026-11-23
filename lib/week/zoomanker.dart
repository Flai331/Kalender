import 'package:flutter/widgets.dart';

/// Woran der Zoom sich festhaelt.
///
/// Rastet die Leiter waehrend eines Zuges feiner, dehnt sich der Tag unter
/// dem Finger auseinander. Irgendeine Stelle auf dem Glas muss dabei ihre
/// Uhrzeit behalten — alle anderen wandern.
///
/// Bisher war das die Mitte des Sichtfeldes. Das ist richtig, solange
/// niemand etwas haelt: man schaut in die Mitte. Waehrend eines Zuges ist es
/// falsch. Das Gezogene rutscht unter dem Finger weg, und je weiter es vom
/// Zentrum entfernt war, desto weiter — bis aus dem Bild. Der Zoom
/// vergroessert dann die Stunde davor statt der, auf die man zielt.
///
/// Also haelt sich der Zoom am Finger fest. Dann bleibt das Gezogene genau
/// dort, wo es liegt, und das Raster waechst darum herum.
///
/// Reine Rechnung: kein Bildschirm, keine Uhr.
class Zoomanker {
  /// Der Abstand vom oberen Rand des Sichtfeldes, an dem die Uhrzeit stehen
  /// bleiben soll.
  ///
  /// Ohne laufenden Zug (oder wenn niemand weiss, wo der Finger ist) die
  /// Mitte — dann schaut man wirklich dorthin.
  static double anker({
    required Offset? zeigerPunkt,
    required Rect? sichtfeld,
    required bool zugLaeuft,
  }) {
    if (!zugLaeuft || zeigerPunkt == null || sichtfeld == null) {
      return (sichtfeld?.height ?? 0) / 2;
    }
    return (zeigerPunkt.dy - sichtfeld.top).clamp(0.0, sichtfeld.height);
  }

  /// Wohin die Ansicht springen muss, damit die Stelle [anker] dieselbe
  /// Uhrzeit behaelt.
  ///
  /// [faktor] ist die neue Stundenhoehe geteilt durch die alte.
  static double neueStelle({
    required double stelle,
    required double anker,
    required double faktor,
    required double hoechstens,
  }) =>
      ((stelle + anker) * faktor - anker).clamp(0.0, hoechstens);
}
