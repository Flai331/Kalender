import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/services/offline_error.dart';

void main() {
  group('isOfflineError', () {
    test('erkennt den Supabase-Fehler aus dem Fehlerbericht vom 22.08.', () {
      // Original-Meldung aus dem Protokoll: Speichern schlug fehl, weil das
      // Handy offline war — der Speichern-Knopf reagierte danach nicht mehr.
      const msg =
          "AuthRetryableFetchException(message: ClientException with "
          "SocketException: Failed host lookup: "
          "'bvwppinkkuolvtxjeiue.supabase.co' (OS Error: No address associated "
          "with hostname, errno = 7), uri=https://bvwppinkkuolvtxjeiue."
          "supabase.co/auth/v1/token?grant_type=refresh_token, statusCode: null)";
      expect(isOfflineError(msg), isTrue);
    });

    test('erkennt weitere Netzwerkfehler', () {
      expect(isOfflineError('SocketException: Connection failed'), isTrue);
      expect(isOfflineError('Connection refused'), isTrue);
      expect(isOfflineError('Connection timed out'), isTrue);
    });

    test('meldet echte Fehler nicht als Offline-Fehler', () {
      expect(isOfflineError('PostgrestException: row-level security'), isFalse);
      expect(isOfflineError(const FormatException('bad json')), isFalse);
    });
  });
}
