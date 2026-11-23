import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/week/planungsvorrat.dart';

/// Die Wochenansicht haelt nur, was sie zeigt. Die Suche nach einem Platz
/// geht aber 30 Tage voraus — und sah dahinter nur leere Tage: der naechste
/// Dienst galt als nicht vorhanden, das To-do fand „keinen Platz".
///
/// Der Vorrat ist der Zettel, den die Suche dafuer bekommt.
void main() {
  final montag = DateTime(2026, 11, 23);
  final dienstag = DateTime(2026, 11, 24);
  final freitag = DateTime(2026, 11, 27);

  CalendarEvent termin(
    String id,
    DateTime tag, {
    int von = 8,
    int bis = 16,
    String kategorie = 'work',
    bool nurInfo = false,
    bool ganztags = false,
  }) =>
      CalendarEvent(
        id: id,
        title: id,
        startTime: DateTime(tag.year, tag.month, tag.day, von),
        endTime: DateTime(tag.year, tag.month, tag.day, bis),
        category: kategorie,
        source: 'app',
        infoOnly: nurInfo,
        isAllDay: ganztags,
      );

  group('Was an einem Tag steht', () {
    test('nur die Termine dieses Tages', () {
      final vorrat = Planungsvorrat.aus([
        termin('mo', montag),
        termin('di', dienstag),
        termin('fr', freitag),
      ]);
      expect(vorrat.amTag(montag).map((e) => e.id), ['mo']);
      expect(vorrat.amTag(freitag).map((e) => e.id), ['fr']);
      expect(vorrat.amTag(DateTime(2026, 11, 25)), isEmpty);
    });

    test('in zeitlicher Reihenfolge', () {
      // Die Suche nimmt den ersten Termin, in den das To-do passt — kommt
      // der spaetere zuerst, landet es unnoetig weit hinten.
      final vorrat = Planungsvorrat.aus([
        termin('spaet', montag, von: 14, bis: 18),
        termin('frueh', montag, von: 6, bis: 10),
      ]);
      expect(vorrat.amTag(montag).map((e) => e.id), ['frueh', 'spaet']);
    });

    test('ein Ganztagstermin steht nicht dazwischen', () {
      final vorrat =
          Planungsvorrat.aus([termin('urlaub', montag, ganztags: true)]);
      expect(vorrat.amTag(montag), isEmpty,
          reason: 'ein ganzer Tag ist kein Zeitfenster');
    });

    test('der Tag zaehlt nach dem Anfang, nicht nach dem Ende', () {
      // Eine Nachtschicht gehoert zu dem Tag, an dem sie anfaengt.
      final nacht = CalendarEvent(
        id: 'nacht',
        title: 'Nacht',
        startTime: DateTime(2026, 11, 23, 22),
        endTime: DateTime(2026, 11, 24, 6),
        category: 'work',
        source: 'app',
      );
      final vorrat = Planungsvorrat.aus([nacht]);
      expect(vorrat.amTag(montag).map((e) => e.id), ['nacht']);
      expect(vorrat.amTag(dienstag), isEmpty);
    });
  });

  group('Termine nur zur Kenntnis', () {
    final vorrat = Planungsvorrat.aus([
      termin('eigen', montag),
      termin('fremd', montag, von: 6, bis: 7, nurInfo: true),
    ]);

    test('bleiben bei der Suche nach freier Zeit draussen', () {
      expect(vorrat.amTag(montag).map((e) => e.id), ['eigen']);
    });

    test('sind dabei, wenn ein Gastgeber gesucht wird', () {
      expect(vorrat.amTag(montag, mitNurInfo: true).map((e) => e.id),
          ['fremd', 'eigen']);
    });
  });

  group('Gesperrte Tage', () {
    test('ein Urlaubstag sperrt', () {
      final vorrat = Planungsvorrat.aus(
          [termin('urlaub', montag, kategorie: 'vacation', ganztags: true)]);
      expect(vorrat.ganztagsGesperrt(montag, ['vacation']), isTrue);
      expect(vorrat.ganztagsGesperrt(dienstag, ['vacation']), isFalse);
    });

    test('eine andere Kategorie sperrt nicht', () {
      final vorrat = Planungsvorrat.aus(
          [termin('messe', montag, kategorie: 'work', ganztags: true)]);
      expect(vorrat.ganztagsGesperrt(montag, ['vacation']), isFalse);
    });

    test('der Urlaub eines anderen Menschen sperrt nicht', () {
      final vorrat = Planungsvorrat.aus([
        termin('urlaub mama', montag,
            kategorie: 'vacation', ganztags: true, nurInfo: true)
      ]);
      expect(vorrat.ganztagsGesperrt(montag, ['vacation']), isFalse);
    });

    test('ein Termin mit Uhrzeit sperrt den Tag nie', () {
      final vorrat =
          Planungsvorrat.aus([termin('dienst', montag, kategorie: 'vacation')]);
      expect(vorrat.ganztagsGesperrt(montag, ['vacation']), isFalse);
    });
  });

  group('Der leere Vorrat', () {
    test('sagt, dass er leer ist', () {
      expect(Planungsvorrat.leer.istLeer, isTrue);
      expect(Planungsvorrat.aus(const []).istLeer, isTrue);
      expect(Planungsvorrat.aus([termin('mo', montag)]).istLeer, isFalse);
    });

    test('antwortet trotzdem', () {
      expect(Planungsvorrat.leer.amTag(montag), isEmpty);
      expect(Planungsvorrat.leer.ganztagsGesperrt(montag, ['vacation']),
          isFalse);
    });
  });
}
