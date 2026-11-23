import 'dart:math' as math;

import '../models/vorlage.dart';

/// Welche Vorlage zu dem passt, was gerade getippt wird.
///
/// Verzeiht Tippfehler: wer „Diesnt" schreibt, meint „Dienst". Das ist kein
/// Luxus — getippt wird einhaendig, unterwegs, und ein Vorschlag, der beim
/// ersten Vertipper verschwindet, ist keiner.
///
/// Reine Rechnung: keine Datenbank, keine Uhr, kein Bildschirm.
class Vorlagensuche {
  /// Wie viele Vorschlaege hoechstens erscheinen. Mehr als eine Handvoll
  /// liest ohnehin niemand, und die Liste verdeckt den halben Bildschirm.
  static const int hoechstens = 5;

  /// Die passenden Vorlagen, die beste zuerst.
  ///
  /// Bei leerer Eingabe die zuletzt benutzten: dann hat man das Feld eben
  /// angetippt und will sehen, was da ist.
  static List<Vorlage> passend(
    List<Vorlage> vorrat,
    String eingabe, {
    int anzahl = hoechstens,
  }) {
    final e = schlicht(eingabe);
    final bewertet = <({Vorlage v, int rang})>[];
    for (final v in vorrat) {
      final rang = e.isEmpty ? 0 : bewertung(v.name, eingabe);
      if (rang == null) continue;
      bewertet.add((v: v, rang: rang));
    }
    bewertet.sort((a, b) {
      if (a.rang != b.rang) return a.rang.compareTo(b.rang);
      // Gleich gut getroffen: die zuletzt benutzte zuerst.
      final zeit = b.v.zuletztBenutzt.compareTo(a.v.zuletztBenutzt);
      if (zeit != 0) return zeit;
      return a.v.name.toLowerCase().compareTo(b.v.name.toLowerCase());
    });
    return bewertet.take(anzahl).map((p) => p.v).toList();
  }

  /// Wie gut [name] zu [eingabe] passt — **kleiner ist besser**, `null`
  /// heisst: passt nicht.
  ///
  /// Die Stufen von oben nach unten: genau, Anfang, Wortanfang, irgendwo
  /// enthalten, und erst danach die Tippfehler.
  static int? bewertung(String name, String eingabe) {
    final n = schlicht(name);
    final e = schlicht(eingabe);
    if (e.isEmpty) return 0;
    if (n.isEmpty) return null;

    if (n == e) return 0;
    if (n.startsWith(e)) return 1;
    if (woerter(n).any((w) => w.startsWith(e))) return 2;
    if (n.contains(e)) return 3;

    final grenze = nachsicht(e);
    // Unter vier Zeichen wird nichts verziehen: bei „Di" passt sonst halb
    // alles, und falsche Vorschlaege sind schlimmer als gar keine.
    if (grenze == 0) return null;

    // Vertippt am Anfang: gegen den **Anfang** des Namens messen, nicht
    // gegen den ganzen. Sonst zaehlte „Dienst Spaet" gegenueber „Diesnt"
    // jeden weiteren Buchstaben als Fehler.
    final d = _amAnfang(n, e, grenze);
    if (d <= grenze) return 4 + d;

    // Vertippt in einem spaeteren Wort: „spet" fuer „Dienst Spaet".
    var bestes = grenze + 1;
    for (final w in woerter(n).skip(1)) {
      final dw = _amAnfang(w, e, grenze);
      if (dw < bestes) bestes = dw;
    }
    if (bestes <= grenze) return 7 + bestes;

    return null;
  }

  /// Der kleinste Abstand zwischen [eingabe] und einem Anfangsstueck von
  /// [name].
  ///
  /// Nicht nur das gleich lange Stueck: wer einen Buchstaben vergisst
  /// („Dinst"), muesste sonst gegen „diens" antreten — zwei Fehler statt
  /// einem. Darum alle Laengen im Umkreis der Nachsicht, und davon die
  /// beste.
  static int _amAnfang(String name, String eingabe, int grenze) {
    final von = math.max(1, eingabe.length - grenze);
    final bis = math.min(name.length, eingabe.length + grenze);
    if (bis < von) return abstand(name, eingabe);
    var bestes = name.length + eingabe.length;
    for (var l = von; l <= bis; l++) {
      final d = abstand(name.substring(0, l), eingabe);
      if (d < bestes) bestes = d;
    }
    return bestes;
  }

  /// Wie viele Fehler bei dieser Laenge noch durchgehen.
  static int nachsicht(String eingabe) => (eingabe.length ~/ 4).clamp(0, 3);

  /// Kleinschreibung, Umlaute ausgeschrieben, Satzzeichen weg.
  ///
  /// „Spät", „Spaet" und „SPÄT" sind dasselbe Wort; wer es eilig hat,
  /// schreibt keine Umlaute.
  static String schlicht(String s) {
    final b = StringBuffer();
    for (final z in s.toLowerCase().runes) {
      switch (String.fromCharCode(z)) {
        case 'ä':
          b.write('ae');
        case 'ö':
          b.write('oe');
        case 'ü':
          b.write('ue');
        case 'ß':
          b.write('ss');
        case 'é' || 'è' || 'ê':
          b.write('e');
        case 'á' || 'à' || 'â':
          b.write('a');
        case final zeichen:
          final c = zeichen.codeUnitAt(0);
          final istBuchstabe = (c >= 97 && c <= 122) || (c >= 48 && c <= 57);
          b.write(istBuchstabe ? zeichen : ' ');
      }
    }
    return b.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<String> woerter(String schlichter) =>
      schlichter.split(' ').where((w) => w.isNotEmpty).toList();

  /// Abstand nach Damerau-Levenshtein (eingeschraenkt): Einfuegen, Loeschen,
  /// Ersetzen — und **Vertauschen benachbarter Zeichen als ein** Fehler.
  ///
  /// Das Vertauschen ist der Grund, warum hier nicht das einfache
  /// Levenshtein steht: „Diesnt" statt „Dienst" ist der haeufigste
  /// Tippfehler ueberhaupt und waere sonst zwei Fehler wert statt einem.
  static int abstand(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var vorvorige = List<int>.filled(b.length + 1, 0);
    var vorige = List<int>.generate(b.length + 1, (i) => i);
    var jetzige = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      jetzige[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final kosten = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var wert = math.min(
          jetzige[j - 1] + 1,
          math.min(vorige[j] + 1, vorige[j - 1] + kosten),
        );
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          wert = math.min(wert, vorvorige[j - 2] + 1);
        }
        jetzige[j] = wert;
      }
      final frei = vorvorige;
      vorvorige = vorige;
      vorige = jetzige;
      jetzige = frei;
    }
    return vorige[b.length];
  }
}
