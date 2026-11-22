import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Was im Manifest fehlt, faellt nicht auf: es gibt keinen Fehler, es
/// passiert nur nichts. Genau so sind die geplanten Meldungen jahrelang
/// still ausgefallen — der Wecker wurde gestellt, aber niemand nahm ab.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  bool hat(String name) => manifest.contains('android:name="$name"');

  group('Geplante Meldungen brauchen ihre Empfaenger', () {
    test('AlarmManager schickt die Meldung an diesen Empfaenger', () {
      expect(
          hat('com.dexterous.flutterlocalnotifications.'
              'ScheduledNotificationReceiver'),
          isTrue,
          reason: 'ohne ihn zeigt keine geplante Meldung sich je — weder '
              'Serien-Erinnerung noch Ortsvorschlag noch Abfahrt');
    });

    test('nach einem Neustart muessen die Wecker neu gestellt werden', () {
      expect(
          hat('com.dexterous.flutterlocalnotifications.'
              'ScheduledNotificationBootReceiver'),
          isTrue,
          reason: 'AlarmManager vergisst beim Ausschalten alles');
      for (final aktion in [
        'android.intent.action.BOOT_COMPLETED',
        // Die App aktualisiert sich selbst — das ist dasselbe Vergessen.
        'android.intent.action.MY_PACKAGE_REPLACED',
      ]) {
        expect(hat(aktion), isTrue, reason: '$aktion fehlt im intent-filter');
      }
    });
  });

  group('Rechte', () {
    test('weckgenau stellen darf die App ohne Nachfrage', () {
      expect(hat('android.permission.USE_EXACT_ALARM'), isTrue,
          reason: 'SCHEDULE_EXACT_ALARM allein ist ab Android 14 verweigert, '
              'bis der Benutzer es von Hand erlaubt');
      expect(hat('android.permission.SCHEDULE_EXACT_ALARM'), isTrue,
          reason: 'fuer Android 12 und 13');
    });

    test('Meldungen zeigen und nach dem Neustart wieder stellen', () {
      expect(hat('android.permission.POST_NOTIFICATIONS'), isTrue);
      expect(hat('android.permission.RECEIVE_BOOT_COMPLETED'), isTrue);
    });
  });
}
