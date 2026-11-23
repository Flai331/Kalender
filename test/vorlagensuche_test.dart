import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/models/vorlage.dart';
import 'package:kalender/vorlagen/vorlagensuche.dart';

/// Getippt wird einhaendig und unterwegs. Ein Vorschlag, der beim ersten
/// Vertipper verschwindet, ist keiner.
void main() {
  Vorlage v(String name, {int tageHer = 0}) => Vorlage(
        id: name,
        art: Vorlagenart.termin,
        name: name,
        felder: const {},
        zuletztBenutzt: DateTime(2026, 11, 23).subtract(Duration(days: tageHer)),
      );

  List<String> namen(List<Vorlage> vs) => vs.map((x) => x.name).toList();

  group('Schlicht gemacht', () {
    test('Umlaute werden ausgeschrieben', () {
      expect(Vorlagensuche.schlicht('Spät'), 'spaet');
      expect(Vorlagensuche.schlicht('Frühdienst'), 'fruehdienst');
      expect(Vorlagensuche.schlicht('Straße'), 'strasse');
    });

    test('Gross und klein ist dasselbe', () {
      expect(Vorlagensuche.schlicht('DIENST'), 'dienst');
    });

    test('Satzzeichen werden zu Leerraum, Raender fallen weg', () {
      expect(Vorlagensuche.schlicht('  Dienst - Spät!  '), 'dienst spaet');
    });

    test('Ziffern bleiben', () {
      expect(Vorlagensuche.schlicht('Dienst 2'), 'dienst 2');
    });
  });

  group('Der Abstand zweier Woerter', () {
    test('gleich ist null', () {
      expect(Vorlagensuche.abstand('dienst', 'dienst'), 0);
    });

    test('ein fehlender Buchstabe ist einer', () {
      expect(Vorlagensuche.abstand('dienst', 'dinst'), 1);
    });

    test('ein falscher Buchstabe ist einer', () {
      expect(Vorlagensuche.abstand('dienst', 'dienzt'), 1);
    });

    test('zwei vertauschte Nachbarn sind EIN Fehler', () {
      // Der haeufigste Tippfehler ueberhaupt. Mit einfachem Levenshtein
      // waere er zwei wert und floege aus der Nachsicht heraus.
      expect(Vorlagensuche.abstand('dienst', 'diesnt'), 1);
      expect(Vorlagensuche.abstand('spaet', 'spate'), 1);
    });

    test('gegen nichts ist die ganze Laenge', () {
      expect(Vorlagensuche.abstand('', 'abc'), 3);
      expect(Vorlagensuche.abstand('abc', ''), 3);
    });
  });

  group('Die Rangfolge der Treffer', () {
    test('genau schlaegt Anfang schlaegt Wortanfang schlaegt enthalten', () {
      final genau = Vorlagensuche.bewertung('dienst', 'dienst')!;
      final anfang = Vorlagensuche.bewertung('dienst spaet', 'dienst')!;
      final wort = Vorlagensuche.bewertung('spaeter dienst', 'dienst')!;
      final drin = Vorlagensuche.bewertung('wochenenddienst', 'dienst')!;
      expect(genau, lessThan(anfang));
      expect(anfang, lessThan(wort));
      expect(wort, lessThan(drin));
    });

    test('ein Tippfehler zaehlt schlechter als jeder echte Treffer', () {
      final drin = Vorlagensuche.bewertung('wochenenddienst', 'dienst')!;
      final vertippt = Vorlagensuche.bewertung('Dienst Spät', 'Diesnt')!;
      expect(drin, lessThan(vertippt));
    });

    test('was gar nicht passt, bekommt null', () {
      expect(Vorlagensuche.bewertung('Dienst Spät', 'Zahnarzt'), isNull);
    });

    test('Umlaute muessen nicht getippt werden', () {
      expect(Vorlagensuche.bewertung('Dienst Spät', 'spaet'), isNotNull);
      expect(Vorlagensuche.bewertung('Dienst Spät', 'spät'), isNotNull);
    });
  });

  group('Was verziehen wird', () {
    test('unter vier Zeichen gar nichts', () {
      // Bei „Di" passt sonst halb alles, und ein falscher Vorschlag ist
      // schlimmer als keiner.
      expect(Vorlagensuche.nachsicht('di'), 0);
      expect(Vorlagensuche.bewertung('Dienst', 'xi'), isNull);
    });

    test('ab vier Zeichen ein Fehler', () {
      expect(Vorlagensuche.nachsicht('dien'), 1);
      expect(Vorlagensuche.bewertung('Dienst Spät', 'Diesnt'), isNotNull);
      expect(Vorlagensuche.bewertung('Dienst Spät', 'Dinst'), isNotNull);
    });

    test('bei langer Eingabe mehr, aber nie beliebig viel', () {
      expect(Vorlagensuche.nachsicht('dienstplan'), 2);
      expect(Vorlagensuche.nachsicht('a' * 100), 3);
    });

    test('ein Tippfehler in einem spaeteren Wort zaehlt auch', () {
      expect(Vorlagensuche.bewertung('Dienst Spät', 'spet'), isNotNull);
    });
  });

  group('Die Vorschlagsliste', () {
    final vorrat = [
      v('Dienst Spät', tageHer: 1),
      v('Dienst Früh', tageHer: 0),
      v('Zahnarzt', tageHer: 5),
      v('Sport', tageHer: 2),
    ];

    test('ohne Eingabe die zuletzt benutzten zuerst', () {
      expect(namen(Vorlagensuche.passend(vorrat, '')),
          ['Dienst Früh', 'Dienst Spät', 'Sport', 'Zahnarzt']);
    });

    test('der Anfang filtert', () {
      expect(namen(Vorlagensuche.passend(vorrat, 'Dienst')),
          ['Dienst Früh', 'Dienst Spät']);
    });

    test('und verzeiht', () {
      expect(namen(Vorlagensuche.passend(vorrat, 'Diesnt')),
          ['Dienst Früh', 'Dienst Spät']);
    });

    test('was nicht passt, bleibt draussen', () {
      expect(Vorlagensuche.passend(vorrat, 'Kino'), isEmpty);
    });

    test('mehr als eine Handvoll kommt nicht', () {
      final viele = List.generate(20, (i) => v('Dienst $i'));
      expect(Vorlagensuche.passend(viele, 'Dienst').length,
          Vorlagensuche.hoechstens);
    });

    test('bei gleichem Rang entscheidet, was zuletzt dran war', () {
      final a = v('Sport Halle', tageHer: 9);
      final b = v('Sport Draußen', tageHer: 1);
      expect(namen(Vorlagensuche.passend([a, b], 'Sport')),
          ['Sport Draußen', 'Sport Halle']);
    });

    test('eine leere Liste bleibt leer', () {
      expect(Vorlagensuche.passend(const [], 'Dienst'), isEmpty);
      expect(Vorlagensuche.passend(const [], ''), isEmpty);
    });
  });
}
