import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/week/randzug.dart';
import 'package:kalender/week/week_day_column.dart';

/// Ein Zug endete bisher am Bildschirmrand. Wer um 9 Uhr anfasst und auf 18
/// Uhr will, muesste loslassen, scrollen und neu anfassen — und beim
/// Loslassen liegt das To-do schon irgendwo. Haelt man es jetzt an die Kante,
/// laeuft die Ansicht weiter.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ein Feld von y=100 bis y=400. Die Zone ist 72 tief, die ruhige Mitte
  // liegt also zwischen 172 und 328.
  const feld = Rect.fromLTWH(0, 100, 400, 300);

  double tempo(double y, {double stundenhoehe = 60}) =>
      Randzug.geschwindigkeit(
          zeigerY: y,
          oben: feld.top,
          unten: feld.bottom,
          stundenhoehe: stundenhoehe);

  group('Wie schnell gelaufen wird', () {
    test('in der Mitte gar nicht', () {
      expect(tempo(250), 0);
      expect(tempo(172), 0);
      expect(tempo(328), 0);
    });

    test('an der Unterkante am schnellsten — vier Stunden je Sekunde', () {
      expect(tempo(400), 4 * 60);
    });

    test('an der Oberkante genauso, nur nach oben', () {
      expect(tempo(100), -4 * 60);
    });

    test('am inneren Rand der Zone langsam, aber nicht null', () {
      // Faengt der Lauf bei null an, passiert im ersten Drittel der Zone
      // sichtbar nichts, und es wirkt, als ginge es nicht.
      // Ein Pixel innerhalb der Zone: schon in Bewegung, aber nur eben.
      expect(tempo(329), closeTo(0.5 * 60, 5));
      expect(tempo(171), closeTo(-0.5 * 60, 5));
    });

    test('mittendrin in der Zone dazwischen', () {
      final v = tempo(364); // halbe Zone
      expect(v, greaterThan(0.5 * 60));
      expect(v, lessThan(4 * 60));
    });

    test('jenseits der Kante bleibt es beim schnellsten Lauf', () {
      // Der Finger darf die Ansicht verlassen — „drunter gehen" heisst
      // genau das. Schneller wird es dadurch nicht.
      expect(tempo(900), 4 * 60);
      expect(tempo(-500), -4 * 60);
    });

    test('das Tempo haengt an der Zoomstufe, nicht an den Pixeln', () {
      // Dieselbe Pixelzahl heisst bei 60 px je Stunde einen halben Tag und
      // bei 720 px je Stunde ein paar Minuten. Gelaufen wird in Stunden.
      expect(tempo(400, stundenhoehe: 720), 4 * 720);
      expect(tempo(400, stundenhoehe: 150), 4 * 150);
    });

    test('ein niedriges Feld behaelt eine ruhige Mitte', () {
      // Sonst ueberlappen sich die beiden Zonen und es gibt keine Stelle
      // mehr, an der nichts passiert.
      const flach = Rect.fromLTWH(0, 0, 400, 60);
      double v(double y) => Randzug.geschwindigkeit(
          zeigerY: y, oben: flach.top, unten: flach.bottom, stundenhoehe: 60);
      expect(v(30), 0);
      expect(v(0), -4 * 60);
      expect(v(60), 4 * 60);
    });

    test('ein Feld ohne Hoehe laeuft nicht', () {
      expect(
          Randzug.geschwindigkeit(
              zeigerY: 5, oben: 10, unten: 10, stundenhoehe: 60),
          0);
    });
  });

  group('Was der Lauf mit der Ansicht macht', () {
    late ScrollController scroller;
    late Randzug zug;
    var nachgezogen = 0;

    Future<void> baue(WidgetTester t) async {
      nachgezogen = 0;
      scroller = ScrollController();
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: SingleChildScrollView(
              controller: scroller,
              child: const SizedBox(height: 3000, width: 400),
            ),
          ),
        ),
      ));
      // Ein Takt von einer Sekunde macht aus „vier Stunden je Sekunde"
      // genau einen Schritt — damit stehen unten runde Zahlen.
      zug = Randzug(
        scroller: scroller,
        sichtfeld: () => feld,
        stundenhoehe: () => 60,
        nachziehen: () => nachgezogen++,
        takt: const Duration(seconds: 1),
      );
      // Erst halten, dann wegraeumen: die Pruefung auf offene Zeitgeber
      // laeuft vor den Aufraeumern, ein noch laufender Takt liesse jeden
      // Test scheitern.
      addTearDown(scroller.dispose);
    }

    testWidgets('an der Unterkante laeuft sie nach unten', (t) async {
      await baue(t);
      zug.zeiger(const Offset(200, 400));
      zug.schritt();
      zug.halt();
      expect(scroller.offset, 4 * 60.0);
    });

    testWidgets('an der Oberkante wieder zurueck', (t) async {
      await baue(t);
      scroller.jumpTo(1000);
      zug.zeiger(const Offset(200, 100));
      zug.schritt();
      zug.halt();
      expect(scroller.offset, 1000 - 4 * 60.0);
    });

    testWidgets('in der Mitte ruehrt sich nichts', (t) async {
      await baue(t);
      scroller.jumpTo(500);
      zug.zeiger(const Offset(200, 250));
      zug.schritt();
      zug.halt();
      expect(scroller.offset, 500);
      expect(nachgezogen, 0);
    });

    testWidgets('am oberen Anschlag bleibt es bei null', (t) async {
      await baue(t);
      zug.zeiger(const Offset(200, 100));
      zug.schritt();
      zug.halt();
      expect(scroller.offset, 0);
      // Und kein Nachziehen: es hat sich ja nichts bewegt, die Vorschau
      // stuende sonst jeden Takt neu auf derselben Uhrzeit.
      expect(nachgezogen, 0);
    });

    testWidgets('am unteren Anschlag bleibt es beim Ende', (t) async {
      await baue(t);
      final ende = scroller.position.maxScrollExtent;
      scroller.jumpTo(ende);
      zug.zeiger(const Offset(200, 400));
      zug.schritt();
      zug.halt();
      expect(scroller.offset, ende);
      expect(nachgezogen, 0);
    });

    testWidgets('nach jedem Stueck Lauf wird die Vorschau nachgezogen',
        (t) async {
      await baue(t);
      zug.zeiger(const Offset(200, 400));
      zug.schritt();
      zug.schritt();
      zug.halt();
      expect(nachgezogen, 2);
    });

    testWidgets('ohne Zeigerpunkt passiert nichts', (t) async {
      await baue(t);
      zug.schritt();
      expect(scroller.offset, 0);
    });

    testWidgets('halt beendet den Lauf', (t) async {
      await baue(t);
      zug.zeiger(const Offset(200, 400));
      expect(zug.laeuft, isTrue);
      zug.halt();
      expect(zug.laeuft, isFalse);
      // Danach laeuft auch ein Schritt ins Leere.
      zug.schritt();
      expect(scroller.offset, 0);
    });

    testWidgets('der Finger haelt still, die Ansicht laeuft weiter',
        (t) async {
      await baue(t);
      zug.zeiger(const Offset(200, 400));
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      zug.halt();
      // Zwei Takte, ohne dass sich der Finger geruehrt haette.
      expect(scroller.offset, 2 * 4 * 60.0);
    });
  });

  group('Die Vorschau folgt der laufenden Ansicht', () {
    // Der Finger steht still, die Ansicht laeuft unter ihm weg: dieselbe
    // Stelle auf dem Glas ist danach eine andere Uhrzeit. Ohne Nachziehen
    // verspraeche der Platzhalter weiter die alte — und abgelegt wuerde die
    // neue.
    const stelle = Key('einfuegestelle');

    setUp(SnapState.stop);
    tearDown(SnapState.stop);

    testWidgets('nach einem Stueck Lauf steht der Platzhalter woanders',
        (t) async {
      final scroller = ScrollController();
      addTearDown(scroller.dispose);
      final todo = Todo(
        id: 't1',
        title: 'Keller aufräumen',
        estimatedMinutes: 60,
        createdAt: DateTime(2026, 11, 20),
      );

      // 8 bis 20 Uhr bei 60 px je Stunde, aber nur 300 px sichtbar: die
      // Spalte ist viermal so hoch wie ihr Fenster.
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 300,
                width: 300,
                child: SingleChildScrollView(
                  controller: scroller,
                  child: SizedBox(
                    height: 720,
                    width: 300,
                    child: WeekDayColumn(
                      day: DateTime(2026, 11, 23),
                      events: const [],
                      todos: const [],
                      isToday: true,
                      hourHeight: 60,
                      startHour: 8,
                      endHour: 20,
                      onTodoDrop: (_, _, _, _) {},
                      onEventDrop: (_, _, _, _) {},
                      onEventTap: (_) {},
                      onTodoTap: (_) {},
                      onTodoToggleDone: (_) {},
                      showHeader: false,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 60,
                child: LongPressDraggable<Todo>(
                  data: todo,
                  onDragStarted: SnapState.begin,
                  onDragEnd: (_) => SnapState.stop(),
                  feedback: const Material(
                      color: Colors.transparent,
                      child: SizedBox(width: 80, height: 20)),
                  childWhenDragging: const SizedBox(width: 80, height: 20),
                  child: Container(
                      key: const Key('griff'),
                      width: 120,
                      height: 40,
                      color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ));

      final kasten = t.getRect(find.byKey(const Key('griff')));
      final anker = kasten.center.dy - kasten.top;
      final g = await t.startGesture(kasten.center);
      await t.pump(const Duration(milliseconds: 600));
      // Obere Kante des Gezogenen auf 100 px unter dem Spaltenanfang.
      await g.moveTo(Offset(150, 100 + anker));
      await t.pump(const Duration(milliseconds: 300));

      // 100 px unter 8:00 sind 9:40, auf 30 Minuten gerastet 9:30.
      expect(SnapState.currentTimeNotifier.value, '09:30');
      final aufDemGlas = t.getRect(find.byKey(stelle)).top;

      // Die Ansicht laeuft 120 px weiter — zwei Stunden.
      scroller.jumpTo(120);
      SnapState.nachziehen();
      await t.pump();

      // Derselbe Punkt auf dem Glas, zwei Stunden spaeter.
      expect(SnapState.currentTimeNotifier.value, '11:30');
      // Und der Platzhalter steht weiter unter dem Finger: er ist im Inhalt
      // mitgelaufen, auf dem Bildschirm hat er sich nicht geruehrt.
      expect(t.getRect(find.byKey(stelle)).top, closeTo(aufDemGlas, 1));

      await g.up();
      await t.pumpAndSettle();
    });
  });

  group('Wann ein Zug als laufend gilt', () {
    tearDown(SnapState.stop);

    test('ab dem ersten Augenblick, nicht erst wenn der Finger ruht', () {
      SnapState.stop();
      expect(SnapState.zugLaeuft.value, isFalse);
      SnapState.begin();
      expect(SnapState.zugLaeuft.value, isTrue);
      // isDraggingNotifier geht erst mit resume() an — der Sog darf nicht
      // auf die Zoom-Leiter warten.
      expect(SnapState.isDraggingNotifier.value, isFalse);
    });

    test('und bis zum Ende des Zuges', () {
      SnapState.begin();
      SnapState.stop();
      expect(SnapState.zugLaeuft.value, isFalse);
    });
  });
}
