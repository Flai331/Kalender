/// Erkennt Netzwerk-/Offline-Fehler anhand ihrer Fehlermeldung.
///
/// Bewusst ohne Imports (kein `dart:io`, kein Supabase), damit die Funktion
/// im Web-Build funktioniert und ohne `secrets.dart` testbar bleibt.
bool isOfflineError(Object error) {
  final s = error.toString();
  return s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('ClientException') ||
      s.contains('AuthRetryableFetchException') ||
      s.contains('Connection closed') ||
      s.contains('Connection refused') ||
      s.contains('Connection timed out');
}
