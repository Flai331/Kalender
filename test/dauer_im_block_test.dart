import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/week/event_block.dart';

/// Im Terminblock stand die Uhrzeit zusammen mit Abfahrt und Heimkehr:
/// "🚗07:40  08:00 – 09:00  🏠09:20". In einer Tagesspalte von 52 px blieb
/// davon "🚗07:40 08…" stehen — man las die Abfahrt statt des Termins.
///
/// Jetzt steht dort die Dauer, kurz genug für die schmalste Spalte.
void main() {
  group('Unter einer Stunde in Minuten', () {
    test('20 Minuten', () => expect(EventBlock.dauerText(20), '20 min'));
    test('45 Minuten', () => expect(EventBlock.dauerText(45), '45 min'));
    test('59 Minuten', () => expect(EventBlock.dauerText(59), '59 min'));
  });

  group('Volle Stunden ohne Rest', () {
    test('eine Stunde', () => expect(EventBlock.dauerText(60), '1 Std'));
    test('zwei Stunden', () => expect(EventBlock.dauerText(120), '2 Std'));
    test('eine Schicht', () => expect(EventBlock.dauerText(480), '8 Std'));
  });

  group('Viertelstunden als Bruch', () {
    // Ausgeschrieben ("1 Std 30 min") braucht 50 px. In der Wochenspalte
    // sind rund 37 px Platz, es wurde zu "1 Std …" abgeschnitten.
    test('Viertel', () => expect(EventBlock.dauerText(75), '1¼ Std'));
    test('halb', () => expect(EventBlock.dauerText(90), '1½ Std'));
    test('Dreiviertel', () => expect(EventBlock.dauerText(105), '1¾ Std'));
    test('zweieinhalb', () => expect(EventBlock.dauerText(150), '2½ Std'));
  });

  group('Krumme Reste', () {
    // Lieber ganz in Minuten als eine gerundete — also falsche — Stundenzahl.
    test('80 Minuten', () => expect(EventBlock.dauerText(80), '80 min'));
    test('100 Minuten', () => expect(EventBlock.dauerText(100), '100 min'));
  });

  group('Kurz genug für die schmalste Spalte', () {
    test('keine Angabe wird länger als acht Zeichen', () {
      for (var m = 1; m <= 24 * 60; m++) {
        expect(EventBlock.dauerText(m).length, lessThanOrEqualTo(8),
            reason: '$m Minuten ergeben "${EventBlock.dauerText(m)}"');
      }
    });
  });
}
