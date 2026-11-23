import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Der Sog am Rand: haelt man etwas Gezogenes an die obere oder untere Kante
/// der Zeitachse, laeuft die Ansicht dorthin weiter.
///
/// Ohne das endet ein Zug am Bildschirmrand. Wer um 9 Uhr anfasst und auf 18
/// Uhr will, muesste loslassen, scrollen und neu anfassen — und beim
/// Loslassen liegt das To-do schon irgendwo.
///
/// Das Tempo steht in **Stunden je Sekunde**, nicht in Pixeln. Dieselbe
/// Pixelzahl heisst bei 60 px je Stunde einen halben Tag und bei 720 px je
/// Stunde ein paar Minuten; der Lauf muss sich nach der Zeitachse richten,
/// nicht nach dem Bildschirm.
class Randzug {
  Randzug({
    required this.scroller,
    required this.sichtfeld,
    required this.stundenhoehe,
    required this.nachziehen,
    this.takt = const Duration(milliseconds: 16),
  });

  /// Die Ansicht, die laufen soll.
  final ScrollController scroller;

  /// Das sichtbare Stueck Zeitachse in Bildschirmkoordinaten — `null`,
  /// solange es keins gibt (Monatsansicht, noch nicht gebaut).
  final Rect? Function() sichtfeld;

  /// Pixel je Stunde, so wie die Ansicht gerade steht.
  final double Function() stundenhoehe;

  /// Nach jedem Stueck Lauf aufzurufen: der Finger steht still, aber unter
  /// ihm ist jetzt eine andere Uhrzeit. Ohne das verspraeche die Vorschau
  /// weiter die alte.
  final VoidCallback nachziehen;

  final Duration takt;

  /// Wie tief die empfindliche Zone an jeder Kante ist.
  static const double randzone = 72.0;

  /// Stunden je Sekunde am **inneren** Rand der Zone.
  ///
  /// Nicht null: faengt der Lauf bei null an, passiert im ersten Drittel der
  /// Zone sichtbar nichts, und es wirkt, als ginge es nicht.
  static const double langsam = 0.5;

  /// Stunden je Sekunde ganz aussen — und darueber hinaus, denn der Finger
  /// darf die Ansicht auch verlassen.
  static const double schnell = 4.0;

  Timer? _lauf;
  Offset? _zeiger;

  bool get laeuft => _lauf != null;

  /// Wo der Finger zuletzt stand, solange der Zug laeuft — auch der Zoom
  /// haelt sich daran fest.
  Offset? get zeigerPunkt => _zeiger;

  /// Wo der Finger gerade ist. Der erste Aufruf setzt den Lauf in Gang; er
  /// haelt danach von allein durch, auch wenn der Finger still steht.
  void zeiger(Offset punkt) {
    _zeiger = punkt;
    _lauf ??= Timer.periodic(takt, (_) => schritt());
  }

  /// Zug vorbei.
  void halt() {
    _lauf?.cancel();
    _lauf = null;
    _zeiger = null;
  }

  /// Ein Stueck Lauf. Oeffentlich, damit ein Test ihn ohne Uhr ausloesen
  /// kann.
  void schritt() {
    final punkt = _zeiger;
    final feld = sichtfeld();
    if (punkt == null || feld == null || !scroller.hasClients) return;
    final v = geschwindigkeit(
      zeigerY: punkt.dy,
      oben: feld.top,
      unten: feld.bottom,
      stundenhoehe: stundenhoehe(),
    );
    if (v == 0) return;
    final stelle = scroller.position;
    final neu = (stelle.pixels + v * takt.inMicroseconds / 1000000)
        .clamp(0.0, stelle.maxScrollExtent);
    // Am Anschlag nichts tun: sonst zoege jeder Takt die Vorschau neu durch,
    // obwohl sich nichts bewegt hat.
    if (neu == stelle.pixels) return;
    scroller.jumpTo(neu);
    nachziehen();
  }

  /// Pixel je Sekunde, positiv nach unten. 0 heisst: der Finger ist in der
  /// Mitte, hier laeuft nichts.
  ///
  /// Reine Rechnung.
  static double geschwindigkeit({
    required double zeigerY,
    required double oben,
    required double unten,
    required double stundenhoehe,
  }) {
    final hoehe = unten - oben;
    if (hoehe <= 0) return 0;
    // Bei einem niedrigen Feld wuerden sich zwei volle Zonen ueberlappen;
    // dann gaebe es keine ruhige Mitte mehr.
    final zone = math.min(randzone, hoehe / 3);
    if (zone <= 0) return 0;
    if (zeigerY < oben + zone) {
      return -_tempo((oben + zone - zeigerY) / zone) * stundenhoehe;
    }
    if (zeigerY > unten - zone) {
      return _tempo((zeigerY - (unten - zone)) / zone) * stundenhoehe;
    }
    return 0;
  }

  /// Stunden je Sekunde, je nachdem wie tief man in der Zone steht.
  /// Jenseits der Kante bleibt es beim schnellsten Lauf.
  static double _tempo(double anteil) =>
      langsam + (schnell - langsam) * anteil.clamp(0.0, 1.0);
}
