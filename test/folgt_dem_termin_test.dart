import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/services/local_service.dart';
import 'package:kalender/week/terminbindung.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein To-do, das nur im Dienst erledigt werden kann, gehoert in *den
/// Dienst* — nicht an die Stelle, an der der Dienst mal lag. Wird der Termin
/// verschoben, verliert das To-do seinen Gastgeber; genau daran erkennt die
/// App, dass sie ihm einen neuen suchen muss.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CalendarEvent dienst({
    String id = 'e1',
    required DateTime von,
    required DateTime bis,
    String kategorie = 'work',
    String? abo = 'abo-1',
    bool nurInfo = false,
  }) =>
      CalendarEvent(
        id: id,
        title: id,
        startTime: von,
        endTime: bis,
        category: kategorie,
        source: abo == null ? 'app' : 'ics',
        icsSourceId: abo,
        infoOnly: nurInfo,
      );

  Todo gebunden({
    DateTime? tag,
    int? stunde = 9,
    int minute = 0,
    int dauer = 30,
    int hin = 0,
    int zurueck = 0,
    String? kalender = 'abo-1',
    String? kategorie,
  }) =>
      Todo(
        id: 't1',
        title: 'Abrechnung',
        estimatedMinutes: dauer,
        contextMode: TodoContextMode.categoryEvent,
        requiredCategory: kategorie,
        requiredCalendarId: kalender,
        scheduledDate: tag,
        scheduledStartHour: stunde,
        scheduledStartMinute: minute,
        travelMinutesBefore: hin,
        travelMinutesAfter: zurueck,
        createdAt: DateTime(2026, 11, 20),
      );

  group('Der Block eines To-dos', () {
    test('ist ohne Zeit nicht da', () {
      expect(Terminbindung.block(gebunden(tag: null, stunde: null)), isNull);
    });

    test('geht von der Startzeit bis zum Ende der Schaetzung', () {
      final b = Terminbindung.block(
          gebunden(tag: DateTime(2026, 11, 23), stunde: 9, dauer: 45));
      expect(b!.$1, DateTime(2026, 11, 23, 9, 0));
      expect(b.$2, DateTime(2026, 11, 23, 9, 45));
    });

    test('zaehlt An- und Abfahrt mit', () {
      // Die Platzsuche rechnet sie mit ein — was in einen Termin gelegt
      // wird, passt dort mitsamt Hin- und Rueckweg hinein. Die Pruefung
      // muss denselben Block ansehen, sonst gilt ein To-do als zuhause,
      // dessen Anfahrt laengst davor liegt.
      final b = Terminbindung.block(gebunden(
          tag: DateTime(2026, 11, 23), stunde: 9, dauer: 30, hin: 15, zurueck: 10));
      expect(b!.$1, DateTime(2026, 11, 23, 8, 45));
      expect(b.$2, DateTime(2026, 11, 23, 9, 40));
    });
  });

  group('Steht das To-do noch in einem Termin?', () {
    final tag = DateTime(2026, 11, 23);

    test('ja, wenn der Termin es ganz umschliesst', () {
      final t = gebunden(tag: tag, stunde: 9);
      expect(
          Terminbindung.stehtIn(t, [
            dienst(von: DateTime(2026, 11, 23, 8), bis: DateTime(2026, 11, 23, 16))
          ]),
          isTrue);
    });

    test('ja, wenn es genau an der Kante anliegt', () {
      final t = gebunden(tag: tag, stunde: 8, dauer: 60);
      expect(
          Terminbindung.stehtIn(t, [
            dienst(von: DateTime(2026, 11, 23, 8), bis: DateTime(2026, 11, 23, 9))
          ]),
          isTrue);
    });

    test('nein, wenn es hinten herausragt', () {
      final t = gebunden(tag: tag, stunde: 15, minute: 45);
      expect(
          Terminbindung.stehtIn(t, [
            dienst(von: DateTime(2026, 11, 23, 8), bis: DateTime(2026, 11, 23, 16))
          ]),
          isFalse);
    });

    test('nein, wenn nur die Anfahrt davor herausragt', () {
      final t = gebunden(tag: tag, stunde: 8, minute: 10, hin: 20);
      expect(
          Terminbindung.stehtIn(t, [
            dienst(von: DateTime(2026, 11, 23, 8), bis: DateTime(2026, 11, 23, 16))
          ]),
          isFalse);
    });

    test('nein, wenn der Tag gar keinen Termin hat', () {
      // Der gemeldete Fall: der Dienst ist weg, das To-do steht allein im
      // Nichts und klebt an der Jetzt-Linie.
      expect(Terminbindung.stehtIn(gebunden(tag: tag), const []), isFalse);
    });

    test('nein, wenn der Termin aus einem anderen Kalender kommt', () {
      final t = gebunden(tag: tag, kalender: 'abo-1');
      expect(
          Terminbindung.stehtIn(t, [
            dienst(
                abo: 'abo-2',
                von: DateTime(2026, 11, 23, 8),
                bis: DateTime(2026, 11, 23, 16))
          ]),
          isFalse);
    });

    test('nein, wenn das To-do keine Zeit hat', () {
      expect(
          Terminbindung.stehtIn(gebunden(tag: null, stunde: null), [
            dienst(von: DateTime(2026, 11, 23, 8), bis: DateTime(2026, 11, 23, 16))
          ]),
          isFalse);
    });

    test('ja, in einer Nachtschicht ueber Mitternacht', () {
      // Der Termin faengt am Vortag an; der Aufrufer reicht ihn mit herein.
      // Mit Minuten-im-Tag gerechnet waere das Ende (6:00) vor dem Anfang
      // (22:00) und das To-do faelschlich heimatlos.
      final t = gebunden(tag: DateTime(2026, 11, 24), stunde: 2);
      expect(
          Terminbindung.stehtIn(t, [
            dienst(
                von: DateTime(2026, 11, 23, 22), bis: DateTime(2026, 11, 24, 6))
          ]),
          isTrue);
    });

    test('ein Termin nur zur Kenntnis beherbergt bei gewaehltem Kalender', () {
      final t = gebunden(tag: tag, kalender: 'abo-1');
      expect(
          Terminbindung.stehtIn(t, [
            dienst(
                nurInfo: true,
                von: DateTime(2026, 11, 23, 8),
                bis: DateTime(2026, 11, 23, 16))
          ]),
          isTrue);
    });

    test('ueber die Kategorie allein aber nicht', () {
      final t = gebunden(tag: tag, kalender: null, kategorie: 'work');
      expect(
          Terminbindung.stehtIn(t, [
            dienst(
                nurInfo: true,
                von: DateTime(2026, 11, 23, 8),
                bis: DateTime(2026, 11, 23, 16))
          ]),
          isFalse);
    });
  });

  group('Der gemeldete Fall', () {
    // Ein To-do sass im Dienst am Montag. Der Dienst wandert auf Mittwoch.
    // Montag ist jetzt leer — das To-do steht im Nichts und muss mit.
    final montag = DateTime(2026, 11, 23);

    test('vorher: es steht im Dienst', () {
      final t = gebunden(tag: montag, stunde: 9);
      final vorher = [
        dienst(von: DateTime(2026, 11, 23, 8), bis: DateTime(2026, 11, 23, 16))
      ];
      expect(Terminbindung.stehtIn(t, vorher), isTrue);
    });

    test('nachher: Montag ist leer, es hat keinen Gastgeber mehr', () {
      final t = gebunden(tag: montag, stunde: 9);
      final nachher = <CalendarEvent>[
        // derselbe Termin, nur zwei Tage spaeter
        dienst(von: DateTime(2026, 11, 25, 8), bis: DateTime(2026, 11, 25, 16))
      ];
      // An Montag selbst liegt nichts mehr — der Durchgang reicht nur die
      // Termine von Sonntag und Montag herein, und die sind leer.
      expect(Terminbindung.stehtIn(t, const []), isFalse);
      // Am neuen Tag stuende es wieder zuhause.
      final umgezogen = gebunden(tag: DateTime(2026, 11, 25), stunde: 9);
      expect(Terminbindung.stehtIn(umgezogen, nachher), isTrue);
    });

    test('ein ungebundenes To-do geht das nichts an', () {
      // Es haengt an der Jetzt-Linie und soll da auch bleiben: ueber die
      // Reihenfolge gewoehnlicher To-dos entscheidet der Mensch.
      final frei = Todo(
        id: 't2',
        title: 'test',
        estimatedMinutes: 30,
        scheduledDate: montag,
        scheduledStartHour: 9,
        scheduledStartMinute: 15,
        createdAt: DateTime(2026, 11, 20),
      );
      expect(Terminbindung.brauchtErstenPlatz(frei), isFalse);
    });
  });

  group('Welche To-dos der Durchgang ansieht', () {
    late AppDatabase db;
    final heute = DateTime(2026, 11, 23);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await LocalService.init(db);
    });
    tearDown(() async => db.close());

    Future<void> lege(
      String id, {
      required DateTime? tag,
      int? stunde = 9,
      bool fest = false,
      bool erledigt = false,
      TodoStatus status = TodoStatus.pending,
    }) =>
        LocalService.saveTodo(Todo(
          id: id,
          title: id,
          estimatedMinutes: 30,
          scheduledDate: tag,
          scheduledStartHour: stunde,
          scheduledStartMinute: 0,
          isFixed: fest,
          isCompleted: erledigt,
          status: status,
          createdAt: DateTime(2026, 11, 20),
        ));

    Future<List<String>> ids() async =>
        (await LocalService.getOpenTodosMitZeitAb(heute))
            .map((t) => t.id)
            .toList();

    test('heute und alles danach', () async {
      await lege('heute', tag: heute);
      await lege('naechste-woche', tag: DateTime(2026, 11, 30));
      expect(await ids(), ['heute', 'naechste-woche']);
    });

    test('nicht die Vergangenheit — die holt das Nachholen', () async {
      await lege('gestern', tag: DateTime(2026, 11, 22));
      expect(await ids(), isEmpty);
    });

    test('nicht ohne Uhrzeit — das ist die Leiste unten', () async {
      await lege('ohne', tag: null, stunde: null);
      expect(await ids(), isEmpty);
    });

    test('nicht, was fest ist', () async {
      // "Fest" heisst: die App verschiebt es nicht. Auch nicht hinterher.
      await lege('fest', tag: heute, fest: true);
      expect(await ids(), isEmpty);
    });

    test('nicht, was erledigt ist', () async {
      await lege('fertig', tag: heute, erledigt: true);
      await lege('abgehakt', tag: heute, status: TodoStatus.done);
      expect(await ids(), isEmpty);
    });

    test('der Reihe nach: erst der Tag, dann die Uhrzeit', () async {
      await lege('spaet', tag: heute, stunde: 17);
      await lege('frueh', tag: heute, stunde: 7);
      await lege('morgen', tag: DateTime(2026, 11, 24), stunde: 6);
      expect(await ids(), ['frueh', 'spaet', 'morgen']);
    });
  });
}
