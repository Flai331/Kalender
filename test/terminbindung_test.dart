import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/services/travel_service.dart';
import 'package:kalender/week/terminbindung.dart';

/// Manches laesst sich nur **waehrend** eines Termins tun: die Abrechnung im
/// Dienst, der Anruf im Buero. Dafuer haengt ein To-do an einer Kategorie
/// und/oder an einem Kalender. Hier steht, welcher Termin es dann beherbergen
/// darf — und welcher nicht.
void main() {
  CalendarEvent termin({
    String id = 'e1',
    String kategorie = 'work',
    String? abo,
    bool nurInfo = false,
    bool ganztags = false,
  }) =>
      CalendarEvent(
        id: id,
        title: id,
        startTime: DateTime(2026, 11, 23, 8),
        endTime: DateTime(2026, 11, 23, 16),
        category: kategorie,
        source: abo == null ? 'app' : 'ics',
        icsSourceId: abo,
        infoOnly: nurInfo,
        isAllDay: ganztags,
      );

  Todo todo({String? kategorie, String? kalender}) => Todo(
        id: 't1',
        title: 'Abrechnung',
        estimatedMinutes: 30,
        contextMode: TodoContextMode.categoryEvent,
        requiredCategory: kategorie,
        requiredCalendarId: kalender,
        createdAt: DateTime(2026, 11, 20),
      );

  group('Wann ueberhaupt gebunden ist', () {
    test('ohne Angabe gar nicht', () {
      expect(Terminbindung.gebunden(todo()), isFalse);
    });

    test('eine Kategorie reicht', () {
      expect(Terminbindung.gebunden(todo(kategorie: 'work')), isTrue);
    });

    test('ein Kalender allein reicht auch', () {
      // Das ist das Neue: „nur im Dienstplan", ohne ueber Kategorien zu
      // reden. Ein Dienstplan hat nur eine Sorte Termine.
      expect(Terminbindung.gebunden(todo(kalender: 'abo-1')), isTrue);
    });

    test('nur in zwei von vier Planungsmodi', () {
      expect(Terminbindung.giltFuer(TodoContextMode.categoryEvent), isTrue);
      expect(Terminbindung.giltFuer(TodoContextMode.opportunistic), isTrue);
      expect(Terminbindung.giltFuer(TodoContextMode.anyTime), isFalse);
      expect(Terminbindung.giltFuer(TodoContextMode.freeTime), isFalse);
    });
  });

  group('Welcher Termin beherbergen darf', () {
    test('ohne Bedingung keiner', () {
      // Sonst wuerde aus „nur im Termin" ein „irgendwann".
      expect(Terminbindung.passt(termin()), isFalse);
    });

    test('die Kategorie muss stimmen', () {
      expect(Terminbindung.passt(termin(), kategorie: 'work'), isTrue);
      expect(Terminbindung.passt(termin(), kategorie: 'sport'), isFalse);
    });

    test('der eigene Kalender heisst app', () {
      expect(TravelService.ownCalendarId, 'app');
      expect(
          Terminbindung.passt(termin(), kalenderId: TravelService.ownCalendarId),
          isTrue);
    });

    test('ein abonnierter Termin gehoert seinem Abo', () {
      final dienst = termin(abo: 'abo-dienstplan');
      expect(Terminbindung.passt(dienst, kalenderId: 'abo-dienstplan'), isTrue);
      expect(Terminbindung.passt(dienst, kalenderId: 'abo-schule'), isFalse);
      expect(Terminbindung.passt(dienst, kalenderId: 'app'), isFalse,
          reason: 'ein importierter Termin ist kein eigener');
    });

    test('beides zusammen verengt', () {
      final dienst = termin(abo: 'abo-dienstplan', kategorie: 'work');
      expect(
          Terminbindung.passt(dienst,
              kategorie: 'work', kalenderId: 'abo-dienstplan'),
          isTrue);
      expect(
          Terminbindung.passt(dienst,
              kategorie: 'sport', kalenderId: 'abo-dienstplan'),
          isFalse);
    });

    test('ein Ganztagstermin ist kein Zeitfenster', () {
      expect(Terminbindung.passt(termin(ganztags: true), kategorie: 'work'),
          isFalse);
    });
  });

  group('Termine nur zur Kenntnis', () {
    test('beherbergen nicht ueber die Kategorie', () {
      // Importierte Termine tragen alle die Kategorie „work". Ohne diese
      // Regel landete ein To-do „im Termin, Kategorie Arbeit" im Dienst
      // eines anderen Menschen.
      expect(
          Terminbindung.passt(termin(abo: 'abo-mama', nurInfo: true),
              kategorie: 'work'),
          isFalse);
    });

    test('beherbergen, wenn der Kalender ausdruecklich gewaehlt ist', () {
      // „Das mache ich, waehrend sie arbeitet" — eine zulaessige Ansage.
      expect(
          Terminbindung.passt(termin(abo: 'abo-mama', nurInfo: true),
              kalenderId: 'abo-mama'),
          isTrue);
    });
  });

  group('Gastgeber eines Tages', () {
    final tag = [
      termin(id: 'frueh', abo: 'abo-dienstplan'),
      termin(id: 'eigen'),
      termin(id: 'fremd', abo: 'abo-mama', nurInfo: true),
    ];

    test('nur die aus dem gewaehlten Kalender', () {
      final gefunden =
          Terminbindung.gastgeber(tag, todo(kalender: 'abo-dienstplan'));
      expect(gefunden.map((e) => e.id), ['frueh']);
    });

    test('ohne Bindung keiner', () {
      expect(Terminbindung.gastgeber(tag, todo()), isEmpty);
    });

    test('die Reihenfolge bleibt', () {
      final gefunden = Terminbindung.gastgeber(tag, todo(kategorie: 'work'));
      expect(gefunden.map((e) => e.id), ['frueh', 'eigen'],
          reason: 'der fremde Dienst faellt weg, der Rest bleibt in Ordnung');
    });
  });

  group('Gespeichert bleibt gespeichert', () {
    test('die Bindung uebersteht Speichern und Laden', () {
      final t = todo(kategorie: 'work', kalender: 'abo-dienstplan');
      final zurueck = Todo.fromJson(t.toJson());
      expect(zurueck.requiredCalendarId, 'abo-dienstplan');
      expect(zurueck.requiredCategory, 'work');
    });

    test('ein altes To-do ohne das Feld haengt an keinem Kalender', () {
      final alt = todo(kategorie: 'work').toJson()
        ..remove('requiredCalendarId');
      expect(Todo.fromJson(alt).requiredCalendarId, isNull);
    });

    test('copyWith kann die Bindung wieder loesen', () {
      // Das braucht das Entfernen eines Abos — mit dem gewoehnlichen
      // copyWith-Muster waere null „nicht angegeben" und wuerde ignoriert.
      final gebunden = todo(kalender: 'abo-dienstplan');
      expect(gebunden.copyWith(requiredCalendarId: null).requiredCalendarId,
          isNull);
      expect(gebunden.copyWith(title: 'anders').requiredCalendarId,
          'abo-dienstplan',
          reason: 'wer nichts dazu sagt, aendert die Bindung nicht');
    });
  });
}
