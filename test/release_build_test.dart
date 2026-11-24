import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Was im Release-Build fehlt, faellt beim Entwickeln nicht auf.
///
/// Flutter schaltet R8 fuer **jeden** Release-Build selbst ein
/// (`FlutterPlugin.kt`: `releaseBuildType.isMinifyEnabled = true`), im Debug
/// laeuft er gar nicht. Genau darum sind alle geplanten Meldungen im
/// fertigen APK ausgefallen, waehrend auf dem Rechner alles ging: R8 warf
/// die generischen Signaturen weg, und Gson stolperte beim Merken des
/// Weckers ueber seinen eigenen TypeToken.
void main() {
  final datei = File('android/app/proguard-rules.pro');

  group('R8-Regeln fuer den Release-Build', () {
    test('die Datei gibt es', () {
      expect(datei.existsSync(), isTrue,
          reason: 'Flutter haengt android/app/proguard-rules.pro von selbst '
              'an die Release-Regeln — aber nur, wenn es sie gibt');
    });

    test('Gson behaelt seine generischen Signaturen', () {
      final text = datei.readAsStringSync();
      expect(text, contains('-keepattributes Signature'),
          reason: 'ohne sie wirft Gson "TypeToken must be created with a '
              'type argument", und keine geplante Meldung kommt je an');
      expect(
          text,
          contains('class * extends com.google.gson.reflect.TypeToken'),
          reason: 'ab R8 3.0 reicht -keepattributes allein nicht');
    });

    test('die Modelle des Meldungs-Plugins bleiben vollstaendig', () {
      expect(datei.readAsStringSync(),
          contains('-keep class com.dexterous.** { *; }'),
          reason: 'Gson liest und schreibt sie ueber ihre Feldnamen');
    });
  });
}
