import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/services/update_service.dart';

void main() {
  group('ReleaseInfo.tryParse', () {
    test('liest die version.json, die der Workflow erzeugt', () {
      const json = '''
      {
        "buildNumber": 42,
        "channel": "vorschau",
        "branch": "claude/kalender-arbeit-31z75h",
        "commit": "eaed10c",
        "builtAt": "2026-11-16T10:00:00Z",
        "apkUrl": "https://github.com/Flai331/Kalender/releases/download/vorschau/kalender.apk"
      }
      ''';
      final info = ReleaseInfo.tryParse(json, 'vorschau');

      expect(info, isNotNull);
      expect(info!.buildNumber, 42);
      expect(info.branch, 'claude/kalender-arbeit-31z75h');
      expect(info.commit, 'eaed10c');
      expect(info.downloadUrl, endsWith('/vorschau/kalender.apk'));
    });

    test('nimmt die Build-Nummer auch als String', () {
      final info = ReleaseInfo.tryParse('{"buildNumber": "7"}', 'latest');
      expect(info?.buildNumber, 7);
    });

    test('faellt auf die Standard-APK-URL zurueck, wenn apkUrl fehlt', () {
      final info = ReleaseInfo.tryParse('{"buildNumber": 3}', 'latest');
      expect(info!.downloadUrl,
          'https://github.com/Flai331/Kalender/releases/download/latest/kalender.apk');
      expect(info.releaseUrl, endsWith('/releases/tag/latest'));
    });

    test('gibt null zurueck statt zu werfen, wenn die Datei unbrauchbar ist',
        () {
      // Ein defektes Release darf die Pruefung nicht mit einer Exception beenden.
      expect(ReleaseInfo.tryParse('kein json', 'latest'), isNull);
      expect(ReleaseInfo.tryParse('{"buildNumber": "abc"}', 'latest'), isNull);
      expect(ReleaseInfo.tryParse('{}', 'latest'), isNull);
      expect(ReleaseInfo.tryParse('[1,2,3]', 'latest'), isNull);
      expect(ReleaseInfo.tryParse('', 'latest'), isNull);
    });
  });

  group('UpdateService.newestOf', () {
    test('nimmt die hoechste Build-Nummer, egal aus welchem Kanal', () {
      final result = UpdateService.newestOf([
        ReleaseInfo(buildNumber: 10, channel: 'latest'),
        ReleaseInfo(buildNumber: 23, channel: 'vorschau'),
        ReleaseInfo(buildNumber: 5, channel: 'latest'),
      ]);
      expect(result!.buildNumber, 23);
      expect(result.channel, 'vorschau');
    });

    test('kommt mit einem einzelnen Kanal klar', () {
      final result = UpdateService.newestOf(
          [ReleaseInfo(buildNumber: 8, channel: 'latest')]);
      expect(result!.buildNumber, 8);
    });

    test('gibt null zurueck, wenn kein Release gefunden wurde', () {
      expect(UpdateService.newestOf([]), isNull);
    });
  });

  group('URLs', () {
    test('zeigen auf das Release des jeweiligen Kanals', () {
      expect(UpdateService.versionUrl('latest'),
          'https://github.com/Flai331/Kalender/releases/download/latest/version.json');
      expect(UpdateService.releaseUrl('vorschau'),
          'https://github.com/Flai331/Kalender/releases/tag/vorschau');
    });
  });
}
