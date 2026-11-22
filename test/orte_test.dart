import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/db/app_database.dart';
import 'package:kalender/models/place.dart';
import 'package:kalender/services/local_service.dart';
import 'package:kalender/services/place_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Orte mit Öffnungszeiten: mehrere Fitnessstudios, eine Rangliste, und die
/// App sagt, in welches man heute kann. Was hier zaehlt, ist die Entscheidung
/// — welcher Ort kommt oben an, und wann sagt die App "keiner offen".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Montag 2026-11-23 … Sonntag 2026-11-29.
  final montag = DateTime(2026, 11, 23);
  DateTime um(int tagImNovember, int stunde, [int minute = 0]) =>
      DateTime(2026, 11, tagImNovember, stunde, minute);

  OpeningHours zeit(int wochentag, int vonStunde, int bisStunde) =>
      OpeningHours(
        weekday: wochentag,
        fromMinute: vonStunde * 60,
        toMinute: bisStunde * 60,
      );

  /// Mo–Fr gleiche Zeiten.
  List<OpeningHours> werktags(int von, int bis) =>
      [for (var t = 1; t <= 5; t++) zeit(t, von, bis)];

  group('Öffnungszeiten', () {
    test('eine Zeit ohne Dauer ist keine', () {
      expect(zeit(1, 8, 20).isValid, isTrue);
      expect(zeit(1, 8, 8).isValid, isFalse);
      expect(zeit(1, 20, 8).isValid, isFalse);
      expect(OpeningHours(weekday: 8, fromMinute: 0, toMinute: 60).isValid,
          isFalse);
      expect(OpeningHours(weekday: 0, fromMinute: 0, toMinute: 60).isValid,
          isFalse);
    });

    test('Uhrzeit lesbar, auch nach Mitternacht', () {
      expect(OpeningHours.minuteToText(0), '00:00');
      expect(OpeningHours.minuteToText(8 * 60 + 30), '08:30');
      expect(OpeningHours.minuteToText(24 * 60), '24:00');
      expect(OpeningHours.minuteToText(25 * 60), '01:00');
      expect(zeit(1, 8, 20).text, '08:00–20:00');
      expect(zeit(1, 20, 26).text, '20:00–02:00 (nachts)');
    });

    test('offen heisst offen, zu heisst zu', () {
      final ort = Place(id: 'a', name: 'Studio', group: 'G', hours: werktags(8, 20));
      expect(ort.isOpenAt(um(23, 9)), isTrue, reason: 'Montag 9 Uhr');
      expect(ort.isOpenAt(um(23, 7, 59)), isFalse);
      expect(ort.isOpenAt(um(23, 20)), isFalse, reason: 'Schluss ist Schluss');
      expect(ort.isOpenAt(um(27, 9)), isTrue, reason: 'Freitag ist der 27.');
      expect(ort.isOpenAt(um(28, 9)), isFalse, reason: 'Samstag zu');
      expect(ort.isOpenAt(um(29, 9)), isFalse, reason: 'Sonntag zu');
    });

    test('der ganze Termin muss reinpassen, nicht nur der Anfang', () {
      final ort = Place(id: 'a', name: 'Studio', group: 'G', hours: werktags(8, 20));
      expect(ort.isOpenDuring(um(23, 18), um(23, 19, 30)), isTrue);
      expect(ort.isOpenDuring(um(23, 19), um(23, 21)), isFalse,
          reason: 'Termin laeuft ueber den Schluss hinaus');
      expect(ort.isOpenDuring(um(23, 7), um(23, 9)), isFalse);
    });

    test('ueber Mitternacht bleibt ein Fenster', () {
      // Freitag 20:00 bis Samstag 02:00.
      final ort = Place(
        id: 'a',
        name: 'Nachtbad',
        group: 'G',
        hours: [OpeningHours(weekday: 5, fromMinute: 20 * 60, toMinute: 26 * 60)],
      );
      expect(ort.isOpenAt(um(27, 23)), isTrue, reason: 'Freitag 23 Uhr');
      expect(ort.isOpenAt(um(28, 1)), isTrue, reason: 'Samstag 1 Uhr');
      expect(ort.isOpenAt(um(28, 3)), isFalse);
      expect(ort.isOpenDuring(um(27, 23), um(28, 1)), isTrue,
          reason: 'Termin ueber Mitternacht, am Stueck offen');
    });

    test('zwei Fenster am Stueck werden eins', () {
      final ort = Place(
        id: 'a',
        name: 'Mittagspause',
        group: 'G',
        hours: [zeit(1, 8, 12), zeit(1, 12, 18)],
      );
      final fenster = ort.openWindows(um(23, 0), um(24, 0));
      expect(fenster, hasLength(1));
      expect(fenster.first.from, um(23, 8));
      expect(fenster.first.to, um(23, 18));
      expect(ort.isOpenDuring(um(23, 11), um(23, 13)), isTrue);
    });

    test('echte Mittagspause bleibt eine Luecke', () {
      final ort = Place(
        id: 'a',
        name: 'Arzt',
        group: 'G',
        hours: [zeit(1, 8, 12), zeit(1, 14, 18)],
      );
      expect(ort.openWindows(um(23, 0), um(24, 0)), hasLength(2));
      expect(ort.isOpenAt(um(23, 13)), isFalse);
      expect(ort.isOpenDuring(um(23, 11), um(23, 15)), isFalse);
    });

    test('wann ist zu, wann wieder auf', () {
      final ort = Place(id: 'a', name: 'Studio', group: 'G', hours: werktags(8, 20));
      expect(ort.closingAfter(um(23, 9)), um(23, 20));
      expect(ort.closingAfter(um(23, 21)), isNull, reason: 'gerade zu');
      expect(ort.nextOpening(um(23, 21)), um(24, 8), reason: 'morgen frueh');
      expect(ort.nextOpening(um(28, 10)), um(30, 8),
          reason: 'Samstag mittags: erst Montag wieder');
    });

    test('ohne Öffnungszeiten ist immer offen', () {
      final ort = Place(id: 'a', name: 'Park', group: 'G');
      expect(ort.hasHours, isFalse);
      expect(ort.isOpenAt(um(29, 3)), isTrue);
      expect(ort.isOpenDuring(um(29, 3), um(29, 5)), isTrue);
      expect(ort.closingAfter(um(29, 3)), isNull);

      // Eine halb ausgefuellte Zeile aus dem Editor zaehlt nicht als Zeit.
      final halb = Place(
        id: 'b',
        name: 'Halb',
        group: 'G',
        hours: [OpeningHours(weekday: 1, fromMinute: 600, toMinute: 600)],
      );
      expect(halb.hasHours, isFalse);
      expect(halb.isOpenDuring(um(29, 3), um(29, 5)), isTrue);
    });
  });

  group('Entfernung', () {
    test('Luftlinie stimmt grob', () {
      // Hamburg → Bremen, rund 95 km.
      final km = distanceKm(53.5511, 9.9937, 53.0793, 8.8017);
      expect(km, greaterThan(90));
      expect(km, lessThan(102));
      expect(distanceKm(53.5511, 9.9937, 53.5511, 9.9937), closeTo(0, 0.001));
    });

    test('ein paar Strassen weiter sind Meter, nicht Kilometer', () {
      final km = distanceKm(53.5511, 9.9937, 53.5551, 9.9937);
      expect(km, greaterThan(0.4));
      expect(km, lessThan(0.5));
    });
  });

  group('Vorschlag', () {
    // Drei Studios. McFit ist das liebste, Fit/One das zweite,
    // Clever Fit das letzte — aber das naechste.
    final mcfit = Place(
      id: 'mcfit',
      name: 'McFit',
      group: 'Fitnessstudio',
      rank: 0,
      latitude: 53.60,
      longitude: 9.99,
      hours: werktags(8, 20),
    );
    final fitone = Place(
      id: 'fitone',
      name: 'Fit/One',
      group: 'Fitnessstudio',
      rank: 1,
      latitude: 53.57,
      longitude: 9.99,
      hours: [...werktags(6, 23), zeit(6, 9, 18), zeit(7, 9, 18)],
    );
    final cleverfit = Place(
      id: 'clever',
      name: 'Clever Fit',
      group: 'Fitnessstudio',
      rank: 2,
      latitude: 53.5520,
      longitude: 9.9937,
      hours: werktags(8, 20),
    );
    final baecker = Place(
      id: 'b',
      name: 'Baecker',
      group: 'Baeckerei',
      hours: werktags(6, 18),
    );
    final alle = [mcfit, fitone, cleverfit, baecker];

    Future<List<PlaceSuggestion>> frage(
      DateTime von,
      DateTime bis, {
      double? lat = 53.5511,
      double? lon = 9.9937,
    }) =>
        PlaceService.suggest(
          group: 'Fitnessstudio',
          from: von,
          to: bis,
          myLatitude: lat,
          myLongitude: lon,
          places: alle,
        );

    test('die Rangliste entscheidet, nicht die Entfernung', () async {
      final liste = await frage(um(23, 18), um(23, 19, 30));
      expect(liste.map((s) => s.place.id).toList(),
          ['mcfit', 'fitone', 'clever']);
      expect(liste.first.open, isTrue);
      expect(liste.first.distanceKm, greaterThan(5),
          reason: 'das liebste ist das weiteste — und steht trotzdem oben');
    });

    test('andere Gruppen bleiben draussen', () async {
      final liste = await frage(um(23, 10), um(23, 11));
      expect(liste.any((s) => s.place.group == 'Baeckerei'), isFalse);
    });

    test('wer zu hat, rutscht nach unten', () async {
      // Montag 21 Uhr: nur Fit/One hat noch offen.
      final liste = await frage(um(23, 21), um(23, 22));
      expect(liste.first.place.id, 'fitone');
      expect(liste.first.open, isTrue);
      expect(liste.skip(1).every((s) => !s.open), isTrue);
      expect(liste.map((s) => s.place.id).toList(),
          ['fitone', 'mcfit', 'clever'],
          reason: 'unter den geschlossenen gilt die Rangliste weiter');
    });

    test('bester Vorschlag ist der oberste offene', () async {
      final best = await PlaceService.best(
        group: 'Fitnessstudio',
        from: um(23, 21),
        to: um(23, 22),
        places: alle,
      );
      expect(best!.place.id, 'fitone');
      expect(best.closesAt, um(23, 23));
    });

    test('hat keiner offen, schlaegt die App nichts vor', () async {
      // Sonntag 7 Uhr.
      final best = await PlaceService.best(
        group: 'Fitnessstudio',
        from: um(29, 7),
        to: um(29, 8),
        places: alle,
      );
      expect(best, isNull);
    });

    test('bei zu gibt es die naechste Öffnung statt nichts', () async {
      final liste = await frage(um(29, 7), um(29, 8));
      expect(liste.every((s) => !s.open), isTrue);
      final mc = liste.firstWhere((s) => s.place.id == 'mcfit');
      expect(mc.nextOpening, um(30, 8), reason: 'Montag frueh');
      expect(mc.closesAt, isNull);
    });

    test('ohne eigenen Standort keine erfundene Entfernung', () async {
      final liste = await frage(um(23, 10), um(23, 11), lat: null, lon: null);
      expect(liste.every((s) => s.distanceKm == null), isTrue);
      expect(liste.first.distanceText, '');
      expect(liste.map((s) => s.place.id).toList(),
          ['mcfit', 'fitone', 'clever'],
          reason: 'die Rangliste traegt auch allein');
    });

    test('ein Ort ohne Koordinaten faellt nicht raus', () async {
      final ohne = Place(
        id: 'x',
        name: 'Turnhalle',
        group: 'Fitnessstudio',
        rank: 1,
        hours: werktags(8, 20),
      );
      final liste = await PlaceService.suggest(
        group: 'Fitnessstudio',
        from: um(23, 10),
        to: um(23, 11),
        myLatitude: 53.5511,
        myLongitude: 9.9937,
        places: [mcfit, ohne],
      );
      expect(liste.map((s) => s.place.id).toList(), ['mcfit', 'x']);
      expect(liste.last.distanceKm, isNull);
    });

    test('gleicher Rang: dann zaehlt die Entfernung', () async {
      final a = cleverfit.copyWith(rank: 0);
      final liste = await PlaceService.suggest(
        group: 'Fitnessstudio',
        from: um(23, 10),
        to: um(23, 11),
        myLatitude: 53.5511,
        myLongitude: 9.9937,
        places: [mcfit, a],
      );
      expect(liste.first.place.id, 'clever');
    });

    test('wer waehrend des Termins schliesst, ist nicht einfach zu',
        () async {
      // Termin 19:00–21:00. McFit macht um 20 Uhr zu, Fit/One um 23 Uhr.
      final liste = await frage(um(23, 19), um(23, 21));
      final mc = liste.firstWhere((s) => s.place.id == 'mcfit');
      expect(mc.open, isFalse, reason: 'nicht die ganze Zeit');
      expect(mc.openAtStart, isTrue, reason: 'anfangen geht');
      expect(mc.closesDuring, isTrue);
      expect(mc.closesAt, um(23, 20), reason: 'bis dahin kann er trainieren');
      expect(mc.nextOpening, isNull);

      final fit = liste.firstWhere((s) => s.place.id == 'fitone');
      expect(fit.open, isTrue);
      expect(liste.first.place.id, 'fitone',
          reason: 'wer ganz offen hat, steht ueber dem, der frueher zumacht');
    });

    test('halb offen steht ueber ganz zu', () async {
      // Montag 19:00–21:00: McFit (bis 20) und Clever Fit (bis 20) sind
      // halb da, ein frueh schliessender Ort gar nicht.
      final frueh = Place(
        id: 'frueh',
        name: 'Frueh zu',
        group: 'Fitnessstudio',
        rank: 0,
        hours: werktags(8, 17),
      );
      final liste = await PlaceService.suggest(
        group: 'Fitnessstudio',
        from: um(23, 19),
        to: um(23, 21),
        places: [frueh, mcfit],
      );
      expect(liste.map((s) => s.place.id).toList(), ['mcfit', 'frueh'],
          reason: 'trotz schlechterem Rang: bei ihm kann man anfangen');
      expect(liste.last.closesDuring, isFalse);
      expect(liste.last.nextOpening, um(24, 8));
    });

    test('Entfernung als Text: Meter bleiben Meter', () async {
      final liste = await frage(um(23, 10), um(23, 11));
      final nah = liste.firstWhere((s) => s.place.id == 'clever');
      expect(nah.distanceText, endsWith(' m'));
      final weit = liste.firstWhere((s) => s.place.id == 'mcfit');
      expect(weit.distanceText, endsWith(' km'));
    });
  });

  group('Speichern', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await LocalService.init(db);
    });
    tearDown(() async => db.close());

    test('frisch installiert gibt es keine Orte', () async {
      expect(await PlaceService.all(), isEmpty);
      expect(await PlaceService.groups(), isEmpty);
    });

    test('was reingeht, kommt wieder raus — mit Öffnungszeiten', () async {
      final ort = Place(
        id: 'a',
        name: 'McFit',
        group: 'Fitnessstudio',
        address: 'Hauptstrasse 1, Hamburg',
        latitude: 53.5511,
        longitude: 9.9937,
        rank: 3,
        hours: werktags(8, 20),
        note: 'Hantelbank im Keller',
      );
      await LocalService.savePlaces([ort]);
      final zurueck = await PlaceService.all();
      expect(zurueck, hasLength(1));
      expect(zurueck.first, ort);
      expect(zurueck.first.hours, hasLength(5));
      expect(zurueck.first.latitude, closeTo(53.5511, 0.0001));
    });

    test('neuer Ort landet am Ende der Rangliste', () async {
      await PlaceService.add(name: 'McFit', group: 'Fitnessstudio');
      await PlaceService.add(name: 'Fit/One', group: 'Fitnessstudio');
      await PlaceService.add(name: 'Baecker', group: 'Baeckerei');

      final studios = await PlaceService.inGroup('Fitnessstudio');
      expect(studios.map((p) => p.name).toList(), ['McFit', 'Fit/One']);
      expect(studios.map((p) => p.rank).toList(), [0, 1]);
      final baeckereien = await PlaceService.inGroup('Baeckerei');
      expect(baeckereien.single.rank, 0,
          reason: 'jede Gruppe hat ihre eigene Rangliste');
      expect(await PlaceService.groups(), ['Baeckerei', 'Fitnessstudio']);
    });

    test('Rangliste umsortieren', () async {
      final a = await PlaceService.add(name: 'A', group: 'G');
      final b = await PlaceService.add(name: 'B', group: 'G');
      final c = await PlaceService.add(name: 'C', group: 'G');
      await PlaceService.reorder('G', [c.id, a.id, b.id]);
      expect((await PlaceService.inGroup('G')).map((p) => p.name).toList(),
          ['C', 'A', 'B']);
    });

    test('nach dem Loeschen ist die Rangliste ohne Luecke', () async {
      final a = await PlaceService.add(name: 'A', group: 'G');
      final b = await PlaceService.add(name: 'B', group: 'G');
      await PlaceService.add(name: 'C', group: 'G');
      await PlaceService.remove(b.id);
      final uebrig = await PlaceService.inGroup('G');
      expect(uebrig.map((p) => p.name).toList(), ['A', 'C']);
      expect(uebrig.map((p) => p.rank).toList(), [0, 1]);
      expect(uebrig.first.id, a.id);
    });

    test('aendern ueberschreibt, legt nicht doppelt an', () async {
      final ort = await PlaceService.add(name: 'McFit', group: 'Fitnessstudio');
      await PlaceService.save(ort.copyWith(
        name: 'McFit Altona',
        hours: werktags(7, 23),
      ));
      final alle = await PlaceService.all();
      expect(alle, hasLength(1));
      expect(alle.first.name, 'McFit Altona');
      expect(alle.first.hours.first.fromMinute, 7 * 60);
    });

    test('Koordinaten wieder loswerden', () async {
      final ort = Place(
        id: 'a',
        name: 'X',
        group: 'G',
        latitude: 53.5,
        longitude: 9.9,
      );
      await LocalService.savePlaces([ort.copyWith(clearPosition: true)]);
      final zurueck = (await PlaceService.all()).single;
      expect(zurueck.hasPosition, isFalse);
      expect(zurueck.latitude, isNull);
    });

    test('alles loeschen nimmt die Orte mit', () async {
      await PlaceService.add(name: 'McFit', group: 'Fitnessstudio');
      await LocalService.clearAll();
      expect(await PlaceService.all(), isEmpty);
    });

    test('kaputter Inhalt wirft die App nicht aus der Bahn', () async {
      await db.into(db.placesCache).insertOnConflictUpdate(
            PlacesCacheCompanion(
              userId: Value(LocalService.currentUid),
              data: const Value('kein JSON'),
              updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
      expect(await PlaceService.all(), isEmpty);
    });

    test('der Vorschlag liest auch aus der Datenbank', () async {
      await LocalService.savePlaces([
        Place(
          id: 'spaet',
          name: 'Spaeti',
          group: 'Fitnessstudio',
          rank: 1,
          hours: werktags(6, 23),
        ),
        Place(
          id: 'frueh',
          name: 'Frueh zu',
          group: 'Fitnessstudio',
          rank: 0,
          hours: werktags(8, 18),
        ),
      ]);
      final best = await PlaceService.best(
        group: 'Fitnessstudio',
        from: um(23, 20),
        to: um(23, 21),
      );
      expect(best!.place.id, 'spaet',
          reason: 'das liebste hat um 20 Uhr schon zu');
    });
  });

  test('Montag ist Montag', () {
    expect(montag.weekday, DateTime.monday);
  });
}
