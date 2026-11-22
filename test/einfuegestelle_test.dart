import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/models/calendar_event.dart';
import 'package:kalender/models/todo.dart';
import 'package:kalender/week/week_day_column.dart';

/// Waehrend man zieht, soll im Raster stehen, **wo** es landet.
///
/// Der Finger selbst taugt dafuer nicht: er verdeckt die Stelle. Und die
/// Blase am Finger nennt nur eine Uhrzeit — bis man die auf die Zeitachse
/// uebersetzt hat, hat man schon losgelassen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SnapState.stop);
  tearDown(SnapState.stop);

  const stelle = Key('einfuegestelle');

  // Die Spalte geht von 8 bis 14 Uhr bei 60 px je Stunde: 1 px = 1 Minute,
  // der obere Rand ist 8:00. Damit ist jede Pixelzahl unten direkt eine
  // Uhrzeit, ohne Umrechnung im Kopf.
  const spaltenBreite = 300.0;
  const spaltenHoehe = 360.0;

  /// Baut die Tagesspalte mit einem Griff darunter, wie die Todo-Leiste.
  ///
  /// Der Griff ist 120x40 und wird in der Mitte gepackt; `details.offset`
  /// eines Zuges ist damit der Punkt des Fingers minus (60, 20) — die obere
  /// Kante des Gezogenen, und genau die landet auf der Uhrzeit.
  Future<List<({int hour, int minute})>> baue(
    WidgetTester t, {
    required Object daten,
    List<CalendarEvent> events = const [],
    List<Todo> todos = const [],
  }) async {
    final abgelegt = <({int hour, int minute})>[];
    Widget griff(Widget kind) {
      if (daten is Todo) {
        return LongPressDraggable<Todo>(
          data: daten,
          onDragStarted: SnapState.begin,
          onDragEnd: (_) => SnapState.stop(),
          feedback: const Material(
              color: Colors.transparent, child: SizedBox(width: 80, height: 20)),
          childWhenDragging: const SizedBox(width: 80, height: 20),
          child: kind,
        );
      }
      return LongPressDraggable<CalendarEvent>(
        data: daten as CalendarEvent,
        onDragStarted: SnapState.begin,
        onDragEnd: (_) => SnapState.stop(),
        feedback: const Material(
            color: Colors.transparent, child: SizedBox(width: 80, height: 20)),
        childWhenDragging: const SizedBox(width: 80, height: 20),
        child: kind,
      );
    }

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(
              width: spaltenBreite,
              height: spaltenHoehe,
              child: WeekDayColumn(
                day: DateTime(2026, 11, 23),
                events: events,
                todos: todos,
                isToday: true,
                hourHeight: 60,
                startHour: 8,
                endHour: 14,
                onTodoDrop: (_, __, h, m) => abgelegt.add((hour: h, minute: m)),
                onEventDrop: (_, __, h, m) => abgelegt.add((hour: h, minute: m)),
                onEventTap: (_) {},
                onTodoTap: (_) {},
                onTodoToggleDone: (_) {},
                showHeader: false,
              ),
            ),
            SizedBox(
              height: 60,
              child: griff(Container(
                key: const Key('griff'),
                width: 120,
                height: 40,
                color: Colors.blue,
              )),
            ),
          ],
        ),
      ),
    ));
    return abgelegt;
  }

  /// Packt den Griff und zieht so, dass die obere Kante des Gezogenen auf
  /// `minutenAb8` liegt.
  ///
  /// Die 300 ms am Ende sind die Schonzeit: ein To-do aus der Leiste gehoert
  /// zu keinem Tag und wird erst nach 250 ms angenommen. Sie bleiben unter
  /// den 600 ms, nach denen die Zoom-Leiter anlaeuft — das Raster steht hier
  /// also noch auf 30 Minuten.
  Future<TestGesture> ziehe(WidgetTester t, double minutenAb8) async {
    final kasten = t.getRect(find.byKey(const Key('griff')));
    // Gezogen wird an der **oberen Kante** des Blocks: `details.offset` ist
    // der Finger minus der Stelle, an der man zugepackt hat. Der Finger muss
    // also um genau diesen Abstand tiefer stehen als die Zielzeit.
    final anker = kasten.center.dy - kasten.top;
    final g = await t.startGesture(kasten.center);
    await t.pump(const Duration(milliseconds: 600));
    await g.moveTo(Offset(150, minutenAb8 + anker));
    await t.pump(const Duration(milliseconds: 300));
    return g;
  }

  Todo einTodo({int minuten = 60}) => Todo(
        id: 't1',
        title: 'Keller aufräumen',
        estimatedMinutes: minuten,
        createdAt: DateTime(2026, 11, 20),
      );

  group('Der Platzhalter', () {
    testWidgets('steht auf der gerasteten Zeit, in der Hoehe der Dauer',
        (t) async {
      await baue(t, daten: einTodo());
      // 160 Minuten ab 8:00 waeren 10:40; das grobe Raster rundet auf 10:30.
      final g = await ziehe(t, 160);

      expect(find.byKey(stelle), findsOneWidget);
      final kasten = t.getRect(find.byKey(stelle));
      expect(kasten.top, 150, reason: '10:30, nicht die rohen 10:40');
      expect(kasten.height, 60, reason: 'eine Stunde To-do');
      expect(kasten.left, 1);
      expect(kasten.width, spaltenBreite - 2,
          reason: 'volle Spaltenbreite: abgelegt wird auf eine Uhrzeit, die '
              'Aufteilung in Nachbarspalten rechnet die Ansicht erst danach');

      await g.up();
      await t.pumpAndSettle();
    });

    testWidgets('nennt die Uhrzeit, die auch abgelegt wird', (t) async {
      final abgelegt = await baue(t, daten: einTodo());
      final g = await ziehe(t, 160);

      expect(
          find.descendant(
              of: find.byKey(stelle), matching: find.text('10:30 – 11:30')),
          findsOneWidget);

      await g.up();
      await t.pumpAndSettle();
      expect(abgelegt, [(hour: 10, minute: 30)],
          reason: 'Vorschau und Ablegen muessen dieselbe Rechnung nehmen');
    });

    testWidgets('in der schmalen Wochenspalte nur der Beginn', (t) async {
      // Eine Tagesspalte der Wochenansicht ist am Handy rund 52 px breit.
      // '10:30 – 11:30' passt dort nicht und wuerde abgeschnitten.
      final todo = einTodo();
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 52,
                height: spaltenHoehe,
                child: WeekDayColumn(
                  day: DateTime(2026, 11, 23),
                  events: const [],
                  todos: const [],
                  isToday: true,
                  hourHeight: 60,
                  startHour: 8,
                  endHour: 14,
                  onTodoDrop: (_, __, ___, ____) {},
                  onEventDrop: (_, __, ___, ____) {},
                  onEventTap: (_) {},
                  onTodoTap: (_) {},
                  onTodoToggleDone: (_) {},
                  showHeader: false,
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

      final griff = t.getCenter(find.byKey(const Key('griff')));
      final g = await t.startGesture(griff);
      await t.pump(const Duration(milliseconds: 600));
      await g.moveTo(const Offset(26, 180));
      await t.pump(const Duration(milliseconds: 300));

      expect(find.descendant(of: find.byKey(stelle), matching: find.text('10:30')),
          findsOneWidget);

      await g.up();
      await t.pumpAndSettle();
    });

    testWidgets('kommt auch fuer einen gezogenen Termin', (t) async {
      final termin = CalendarEvent(
        id: 'e1',
        title: 'Zahnarzt',
        startTime: DateTime(2026, 11, 23, 9),
        endTime: DateTime(2026, 11, 23, 9, 45),
        category: 'personal',
        source: 'app',
      );
      await baue(t, daten: termin);
      final g = await ziehe(t, 160);

      expect(t.getRect(find.byKey(stelle)).height, 45,
          reason: 'die Dauer des Termins, ohne An- und Abfahrt');

      await g.up();
      await t.pumpAndSettle();
    });
  });

  group('Wann nichts zu sehen ist', () {
    testWidgets('ohne Zug steht kein Platzhalter im Raster', (t) async {
      await baue(t, daten: einTodo());
      expect(find.byKey(stelle), findsNothing);
    });

    testWidgets('in der Schonzeit eines fremden Tages — und danach von '
        'selbst, ohne dass der Finger sich ruehrt', (t) async {
      // Ein To-do aus der Leiste gehoert noch zu keinem Tag. Es wird erst
      // nach 250 ms angenommen, damit es beim Wischen ueber die Woche nicht
      // im falschen Tag landet. Vorher tat ein Loslassen schlicht nichts,
      // ohne dass man das sehen konnte.
      await baue(t, daten: einTodo());
      final griff = t.getCenter(find.byKey(const Key('griff')));
      final g = await t.startGesture(griff);
      await t.pump(const Duration(milliseconds: 600));
      await g.moveTo(const Offset(150, 180));
      await t.pump(const Duration(milliseconds: 100));

      expect(find.byKey(stelle), findsNothing,
          reason: 'noch nimmt der Tag nichts an');

      // Ohne weitere Bewegung: der Platzhalter muss nachkommen, sonst
      // bliebe er aus, obwohl ein Loslassen jetzt ankommt.
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(stelle), findsOneWidget);

      await g.up();
      await t.pumpAndSettle();
    });

    testWidgets('verschwindet, wenn der Finger die Spalte verlaesst',
        (t) async {
      await baue(t, daten: einTodo());
      final g = await ziehe(t, 160);
      expect(find.byKey(stelle), findsOneWidget);

      // Aus der Spalte heraus, nach unten in die Leiste.
      await g.moveTo(const Offset(150, 400));
      await t.pump();
      expect(find.byKey(stelle), findsNothing);

      await g.up();
      await t.pumpAndSettle();
    });

    testWidgets('ist nach dem Ablegen weg', (t) async {
      await baue(t, daten: einTodo());
      final g = await ziehe(t, 160);
      expect(find.byKey(stelle), findsOneWidget);

      await g.up();
      await t.pumpAndSettle();
      expect(find.byKey(stelle), findsNothing);
    });
  });

  group('Feineres Raster', () {
    testWidgets('ruckt den Platzhalter mit, auch wenn der Finger stillsteht',
        (t) async {
      await baue(t, daten: einTodo());
      final g = await ziehe(t, 160);
      expect(t.getRect(find.byKey(stelle)).top, 150, reason: '30er-Raster');

      // Stillhalten laesst die Leiter feiner werden: 30 → 15 → 5. Die rohe
      // Stelle bleibt 10:40, die gerastete wandert — und ohne Nachtragen
      // stuende der Platzhalter weiter auf 10:30, abgelegt wuerde aber auf
      // 10:45 bzw. 10:40.
      await t.pump(const Duration(milliseconds: 2000));
      expect(SnapState.current, 15);
      expect(t.getRect(find.byKey(stelle)).top, 165, reason: '10:45');
      expect(SnapState.currentTimeNotifier.value, '10:45',
          reason: 'die Blase am Finger darf nicht etwas anderes sagen');

      await t.pump(const Duration(milliseconds: 1600));
      expect(SnapState.current, 5);
      expect(t.getRect(find.byKey(stelle)).top, 160, reason: '10:40');
      expect(SnapState.currentTimeNotifier.value, '10:40');

      await g.up();
      await t.pumpAndSettle();
    });
  });
}
