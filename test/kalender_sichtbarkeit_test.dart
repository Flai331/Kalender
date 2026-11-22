import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/models/ics_source.dart';
import 'package:kalender/services/ics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Der Schalter in den Einstellungen blendet einen Kalender aus, statt ihn zu
/// löschen. Hier steht, dass genau das passiert — und dass bestehende
/// Kalender dabei sichtbar bleiben.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const einTermin = '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:abc-1
SUMMARY:Zahnarzt
DTSTART:20260310T090000Z
DTEND:20260310T100000Z
END:VEVENT
END:VCALENDAR''';

  late Directory ordner;
  late File datei;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ordner = await Directory.systemTemp.createTemp('ics_sichtbar');
    datei = File('${ordner.path}/kalender.ics');
    await datei.writeAsString(einTermin);
  });

  tearDown(() async {
    if (ordner.existsSync()) await ordner.delete(recursive: true);
  });

  group('Modell', () {
    test('neuer Kalender ist sichtbar', () {
      const quelle = IcsSource(id: '1', name: 'Arbeit', url: 'https://x/a.ics');
      expect(quelle.visible, isTrue);
    });

    test('Altbestand ohne das Feld bleibt sichtbar', () {
      final quelle = IcsSource.fromJson({
        'id': '1',
        'name': 'Arbeit',
        'url': 'https://x/a.ics',
        'isFile': false,
        'color': null,
        'allowTodoDrop': false,
      });
      expect(quelle.visible, isTrue);
    });

    test('ausgeblendet übersteht das Speichern', () {
      const quelle = IcsSource(id: '1', name: 'Arbeit', url: 'https://x/a.ics');
      final aus = quelle.copyWith(visible: false);
      final zurueck =
          IcsSource.listFromJson(IcsSource.listToJson([aus])).single;
      expect(zurueck.visible, isFalse);
      expect(zurueck.name, 'Arbeit');
    });

    test('Ausblenden lässt Farbe und Todo-Einstellung stehen', () {
      const quelle = IcsSource(
          id: '1',
          name: 'Arbeit',
          url: 'https://x/a.ics',
          color: 0xFF448AFF,
          allowTodoDrop: true);
      final aus = quelle.copyWith(visible: false);
      expect(aus.color, 0xFF448AFF);
      expect(aus.allowTodoDrop, isTrue);
    });
  });

  group('Abruf', () {
    test('sichtbarer Kalender liefert seine Termine', () async {
      await IcsService.addFile(datei.path, 'Arbeit');
      final termine = await IcsService.fetchEvents();
      expect(termine, hasLength(1));
      expect(termine.single.title, 'Zahnarzt');
    });

    test('ausgeblendeter Kalender liefert nichts', () async {
      final quelle = await IcsService.addFile(datei.path, 'Arbeit');
      await IcsService.saveSources([quelle.copyWith(visible: false)]);

      expect(await IcsService.fetchEvents(), isEmpty);
    });

    test('ausgeblendet bleibt in der Liste stehen', () async {
      final quelle = await IcsService.addFile(datei.path, 'Arbeit');
      await IcsService.saveSources([quelle.copyWith(visible: false)]);

      final quellen = await IcsService.getSources();
      expect(quellen, hasLength(1));
      expect(quellen.single.name, 'Arbeit');
      expect(quellen.single.visible, isFalse);
    });

    test('wieder eingeblendet liefert wieder Termine', () async {
      final quelle = await IcsService.addFile(datei.path, 'Arbeit');
      await IcsService.saveSources([quelle.copyWith(visible: false)]);
      await IcsService.saveSources([quelle.copyWith(visible: true)]);

      expect(await IcsService.fetchEvents(), hasLength(1));
    });

    test('nur der ausgeblendete fällt weg, der andere bleibt', () async {
      final zweite = File('${ordner.path}/zweiter.ics');
      await zweite.writeAsString(einTermin.replaceAll('Zahnarzt', 'Sport'));

      final a = await IcsService.addFile(datei.path, 'Arbeit');
      await IcsService.addFile(zweite.path, 'Sport');
      final quellen = await IcsService.getSources();
      await IcsService.saveSources(quellen
          .map((s) => s.id == a.id ? s.copyWith(visible: false) : s)
          .toList());

      final termine = await IcsService.fetchEvents();
      expect(termine.map((e) => e.title), ['Sport']);
    });
  });
}
