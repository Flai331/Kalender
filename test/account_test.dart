import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/services/auth_service.dart';

/// Das Konto war eine anonyme Sitzung: bequem, aber sie lebt nur in dieser
/// Installation. Neues Handy oder neu installierte App, und die Kennung ist
/// weg — die Daten bleiben in Supabase liegen, aber unerreichbar.
///
/// Geprueft wird hier die Pruefung der Eingabe. Alles andere am Konto haengt
/// an einer echten Supabase-Sitzung und laesst sich ohne Server nicht
/// nachstellen.
void main() {
  group('E-Mail-Pruefung', () {
    test('uebliche Adressen gehen durch', () {
      for (final adresse in [
        'a@b.de',
        'klaas.otte@example.com',
        'vor-nach@mail.co.uk',
        'ziffern123@domain.org',
        'plus+tag@gmail.com',
      ]) {
        expect(AuthService.looksLikeEmail(adresse), isTrue, reason: adresse);
      }
    });

    test('Leerzeichen am Rand stoeren nicht', () {
      expect(AuthService.looksLikeEmail('  a@b.de  '), isTrue);
    });

    test('offensichtliche Tippfehler fallen auf', () {
      for (final adresse in [
        '',
        'klaas',
        'klaas@',
        '@example.com',
        'klaas@example',
        'klaas@example.',
        'klaas@@example.de',
        'klaas@.de',
        'klaas otte@example.de',
        'a@b.c d',
      ]) {
        expect(AuthService.looksLikeEmail(adresse), isFalse, reason: adresse);
      }
    });

    test('zwei Adressen in einem Feld fallen auf', () {
      // Zwei @ heisst: das ist keine einzelne Adresse.
      expect(AuthService.looksLikeEmail('a@b.de,c@d.de'), isFalse);
    });

    test('die Mindestlaenge des Passworts entspricht der von Supabase', () {
      expect(AuthService.minPasswordLength, 6);
    });
  });
}
