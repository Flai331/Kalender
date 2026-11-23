import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/week/nachholen.dart';

/// Was gestern liegenblieb, kommt heute **auf jetzt** — nicht auf die alte
/// Uhrzeit. Dass etwas gestern um neun dran war, sagt nichts darueber, was
/// heute um neun los ist.
void main() {
  final tag = DateTime(2026, 11, 23);

  CalendarEvent termin({
    String id = 'e1',
    int vonStd = 8,
    int vonMin = 0,
    int bisStd = 12,
    int bisMin = 0,
    int hin = 0,
    int zurueck = 0,
    bool ganztags = false,
    bool nurInfo = false,
  }) =>
      CalendarEvent(
        id: id,
        title: id,
        startTime: DateTime(tag.year, tag.month, tag.day, vonStd, vonMin),
        endTime: DateTime(tag.year, tag.month, tag.day, bisStd, bisMin),
        category: 'work',
        source: 'app',
        isAllDay: ganztags,
        infoOnly: nurInfo,
        travelMinutesBefore: hin,
        travelMinutesAfter: zurueck,
      );

  Todo todo(String id, {int dauer = 30, int hin = 0, int zurueck = 0}) => Todo(
        id: id,
        title: id,
        estimatedMinutes: dauer,
        // Gestern, neun Uhr — genau die Angabe, die nicht mehr zaehlen soll.
        scheduledDate: DateTime(2026, 11, 22),
        scheduledStartHour: 9,
        scheduledStartMinute: 0,
        travelMinutesBefore: hin,
        travelMinutesAfter: zurueck,
        createdAt: DateTime(2026, 11, 20),
      );

  List<Nachholplatz> plane(List<Todo> todos,
          {List<Zeitblock> belegt = const [], int jetzt = 8 * 60}) =>
      Nachholen.plan(todos: todos, belegt: belegt, jetztMinute: jetzt);

  String uhr(Nachholplatz p) =>
      '${p.stunde.toString().padLeft(2, '0')}:'
      '${p.minute.toString().padLeft(2, '0')}';

  group('Die Jetzt-Kante', () {
    test('liegt fuenf Minuten nach jetzt', () {
      // Was man noch vor sich hat, gehoert unter die Jetzt-Linie. Ein Block,
      // der schon angefangen hat, sieht aus wie etwas Verpasstes.
      expect(Nachholen.vorlauf, 5);
      expect(Nachholen.fruehestens(8 * 60), 8 * 60 + 5);
    });

    test('faellt nicht aus dem Tag heraus', () {
      // Kurz vor Mitternacht gibt es kein "fuenf Minuten spaeter" mehr.
      expect(Nachholen.fruehestens(24 * 60 - 2), 24 * 60 - 1);
      expect(Nachholen.fruehestens(24 * 60 - 1), 24 * 60 - 1);
    });
  });

  group('Was Zeit belegt', () {
    test('ein echter Termin', () {
      expect(Nachholen.belegteZeiten([termin()]), [(480, 720)]);
    });

    test('mit An- und Abfahrt drumherum', () {
      expect(Nachholen.belegteZeiten([termin(hin: 20, zurueck: 10)]),
          [(460, 730)]);
    });

    test('ein Termin nur zur Kenntnis belegt nichts', () {
      // Der Dienstplan eines anderen Menschen ist nicht die eigene Zeit —
      // darueber darf ein To-do ruhig liegen.
      expect(Nachholen.belegteZeiten([termin(nurInfo: true)]), isEmpty);
    });

    test('ein Ganztagstermin auch nicht', () {
      // Sonst waere der ganze Tag weg und nichts liesse sich nachholen.
      expect(Nachholen.belegteZeiten([termin(ganztags: true)]), isEmpty);
    });

    test('der eigene Termin bleibt, der fremde faellt weg', () {
      final zeiten = Nachholen.belegteZeiten([
        termin(id: 'eigen'),
        termin(id: 'fremd', vonStd: 14, bisStd: 18, nurInfo: true),
      ]);
      expect(zeiten, [(480, 720)]);
    });
  });

  group('Ausweichen', () {
    test('vor dem Termin bleibt stehen, wer davor passt', () {
      expect(Nachholen.hinterTermine(450, 30, [(480, 720)]), 450,
          reason: '450 + 30 endet genau, wo der Termin anfaengt');
    });

    test('wer hineinragt, kommt dahinter', () {
      expect(Nachholen.hinterTermine(460, 30, [(480, 720)]), 720);
    });

    test('und dahinter auch noch am naechsten vorbei', () {
      // Wer nur einmal ausweicht, landet mitten im zweiten Termin.
      expect(
          Nachholen.hinterTermine(460, 30, [(480, 720), (720, 780)]), 780);
    });

    test('ohne Termin bleibt alles, wo es ist', () {
      expect(Nachholen.hinterTermine(800, 30, const []), 800);
      expect(Nachholen.hinterTermine(800, 30, [(480, 720)]), 800);
    });
  });

  group('Nachholen', () {
    test('die alte Uhrzeit zaehlt nicht mehr', () {
      final platz = plane([todo('gestern')]).single;
      expect(uhr(platz), '08:05');
      expect(platz.stunde, isNot(9), reason: 'gestern neun Uhr ist vorbei');
    });

    test('mehrere reihen sich hintereinander', () {
      final plaetze =
          plane([todo('erst', dauer: 30), todo('dann', dauer: 45)]);
      expect(plaetze.map(uhr), ['08:05', '08:35']);
    });

    test('ein echter Termin wird umgangen', () {
      // Die Kante liegt schon im Dienst (08:00-12:00) — dahinter also.
      final plaetze = plane([todo('waesche', dauer: 30)],
          belegt: Nachholen.belegteZeiten([termin()]));
      expect(uhr(plaetze.single), '12:00');
    });

    test('ein Termin nur zur Kenntnis wird nicht umgangen', () {
      final plaetze = plane([todo('waesche', dauer: 30)],
          belegt: Nachholen.belegteZeiten([termin(nurInfo: true)]));
      expect(uhr(plaetze.single), '08:05',
          reason: 'darueber darf das To-do liegen');
    });

    test('die Anfahrt zaehlt mit, steht aber nicht in der Uhrzeit', () {
      // Der Block faengt 08:05 an, losgefahren wird dann — das To-do selbst
      // ist 20 Minuten spaeter dran.
      final platz = plane([todo('sport', dauer: 30, hin: 20)]).single;
      expect(uhr(platz), '08:25');
    });

    test('der Heimweg haelt den Platz fuer das naechste frei', () {
      final plaetze = plane([
        todo('erst', dauer: 30, zurueck: 15),
        todo('dann', dauer: 30),
      ]);
      expect(plaetze.map(uhr), ['08:05', '08:50']);
    });

    test('ein voller Tag draengt nicht aus dem Tag heraus', () {
      final plaetze =
          plane([todo('irgendwas')], belegt: const [(0, 24 * 60)]);
      expect(uhr(plaetze.single), '23:59',
          reason: 'lieber ganz unten am Tag als im Nirgendwo');
    });

    test('nichts faengt vor jetzt an', () {
      // Nicht nur die Uhrzeit des To-dos: der ganze Block, Anfahrt
      // eingerechnet, liegt unter der Jetzt-Linie. Sonst haengt die
      // Anfahrt in der Vergangenheit und man ist schon zu spaet los.
      const jetzt = 8 * 60;
      final platz =
          plane([todo('sport', dauer: 30, hin: 20)], jetzt: jetzt).single;
      final blockAnfang = platz.stunde * 60 + platz.minute - 20;
      expect(blockAnfang, greaterThan(jetzt));
    });

    test('nichts liegengeblieben, nichts zu tun', () {
      expect(plane(const []), isEmpty);
    });
  });
}
