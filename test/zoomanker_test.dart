import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/week/zoomanker.dart';

/// Rastet die Zoom-Leiter waehrend eines Zuges feiner, dehnt sich der Tag
/// unter dem Finger auseinander. Eine Stelle auf dem Glas behaelt ihre
/// Uhrzeit — bisher die Mitte, und das Gezogene rutschte darunter weg.
void main() {
  // Sichtfeld von y=100 bis y=500, also 400 hoch; die Mitte liegt bei 200
  // Abstand vom oberen Rand.
  const feld = Rect.fromLTWH(0, 100, 300, 400);

  group('Woran der Zoom sich festhaelt', () {
    test('ohne Zug an der Mitte', () {
      expect(
          Zoomanker.anker(
              zeigerPunkt: const Offset(50, 480),
              sichtfeld: feld,
              zugLaeuft: false),
          200);
    });

    test('mit Zug am Finger', () {
      expect(
          Zoomanker.anker(
              zeigerPunkt: const Offset(50, 460),
              sichtfeld: feld,
              zugLaeuft: true),
          360);
    });

    test('ohne bekannten Finger trotz Zug an der Mitte', () {
      expect(
          Zoomanker.anker(zeigerPunkt: null, sichtfeld: feld, zugLaeuft: true),
          200);
    });

    test('ohne Sichtfeld bei null', () {
      expect(
          Zoomanker.anker(
              zeigerPunkt: const Offset(50, 460),
              sichtfeld: null,
              zugLaeuft: true),
          0);
    });

    test('ein Finger ausserhalb wird auf den Rand geholt', () {
      // Beim Sog am Rand steht er oft unter oder ueber dem Feld. Ein Anker
      // ausserhalb wuerde die Ansicht wegkatapultieren.
      expect(
          Zoomanker.anker(
              zeigerPunkt: const Offset(50, 900),
              sichtfeld: feld,
              zugLaeuft: true),
          400);
      expect(
          Zoomanker.anker(
              zeigerPunkt: const Offset(50, -300),
              sichtfeld: feld,
              zugLaeuft: true),
          0);
    });
  });

  group('Wohin die Ansicht danach springt', () {
    test('die Uhrzeit am Anker bleibt stehen', () {
      // Scrollstand 600, Anker 200 => unter dem Anker liegt Inhalt 800.
      // Doppelte Stundenhoehe macht daraus 1600; damit der wieder unter dem
      // Anker steht, muss der Scrollstand auf 1400.
      expect(
          Zoomanker.neueStelle(
              stelle: 600, anker: 200, faktor: 2, hoechstens: 99999),
          1400);
    });

    test('auch beim Herauszoomen', () {
      expect(
          Zoomanker.neueStelle(
              stelle: 1400, anker: 200, faktor: 0.5, hoechstens: 99999),
          600);
    });

    test('ein Anker ganz oben haelt den oberen Rand', () {
      expect(
          Zoomanker.neueStelle(
              stelle: 300, anker: 0, faktor: 2, hoechstens: 99999),
          600);
    });

    test('nie vor den Anfang', () {
      expect(
          Zoomanker.neueStelle(
              stelle: 0, anker: 200, faktor: 0.5, hoechstens: 99999),
          0);
    });

    test('nie hinter das Ende', () {
      expect(
          Zoomanker.neueStelle(
              stelle: 600, anker: 200, faktor: 4, hoechstens: 1000),
          1000);
    });

    test('ohne Zoomschritt steht alles still', () {
      expect(
          Zoomanker.neueStelle(
              stelle: 742, anker: 137, faktor: 1, hoechstens: 99999),
          742);
    });

    test('der Finger unten haelt das Gezogene unten', () {
      // Der gemeldete Fall: mit der Mitte als Anker wandert die Stelle
      // unter dem Finger weg, mit dem Finger als Anker nicht.
      const stelle = 600.0;
      const fingerAnker = 380.0;
      const mitte = 200.0;
      const faktor = 2.0;

      double unterDemFinger(double neueStelle, double anker) =>
          (stelle + anker) * faktor - neueStelle - anker;

      final mitFinger = Zoomanker.neueStelle(
          stelle: stelle, anker: fingerAnker, faktor: faktor, hoechstens: 99999);
      final mitMitte = Zoomanker.neueStelle(
          stelle: stelle, anker: mitte, faktor: faktor, hoechstens: 99999);

      // Mit dem Finger als Anker: der Inhalt unter ihm hat sich nicht
      // verschoben.
      expect(unterDemFinger(mitFinger, fingerAnker), 0);
      // Mit der Mitte: 180 px daneben — bei 360 px je Stunde eine halbe.
      expect(unterDemFinger(mitMitte, fingerAnker), isNot(0));
    });
  });
}
