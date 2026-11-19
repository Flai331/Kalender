import 'package:supabase_flutter/supabase_flutter.dart';

/// Das Konto, unter dem die Daten in Supabase liegen.
///
/// Angemeldet wird anonym: die App fragt beim ersten Start eine Kennung an
/// und behaelt sie. Das ist bequem — niemand muss sich etwas merken — hat
/// aber einen Preis: die Sitzung lebt nur im Speicher dieser Installation.
/// Geht das Geraet verloren oder wird die App neu installiert, ist die
/// Kennung weg. Die Daten bleiben in Supabase stehen, aber niemand kommt
/// mehr an sie heran.
///
/// Deshalb [bindEmail]: eine Adresse am bestehenden Konto hinterlegen. Es
/// bleibt dasselbe Konto mit derselben Kennung, es bekommt nur einen Namen,
/// unter dem man es wiederfindet.
class AuthService {
  static final _supabase = Supabase.instance.client;

  static User? get currentUser => _supabase.auth.currentUser;
  static String? get userId => _supabase.auth.currentUser?.id;

  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  /// Die bestaetigte Adresse des Kontos, oder null.
  static String? get email {
    final value = currentUser?.email;
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Ob das Konto wiederherstellbar ist. Nur mit bestaetigter Adresse kommt
  /// man auf einem anderen Geraet an seine Daten.
  static bool get hasEmail => email != null;

  /// Eine hinterlegte, aber noch nicht bestaetigte Adresse.
  ///
  /// Supabase legt sie bis zum Klick in der Mail beiseite. Bis dahin zaehlt
  /// sie nicht: das Konto haengt weiter allein an diesem Geraet.
  static String? get pendingEmail {
    final value = currentUser?.newEmail;
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Ob das Konto nur auf diesem Geraet existiert.
  static bool get isDeviceOnly => currentUser != null && !hasEmail;

  static Future<String?> ensureSignedIn() async {
    if (_supabase.auth.currentUser != null) {
      return _supabase.auth.currentUser!.id;
    }
    try {
      final res = await _supabase.auth.signInAnonymously();
      return res.user?.id;
    } catch (e) {
      return null;
    }
  }

  /// Hinterlegt Adresse und Passwort am bestehenden Konto.
  ///
  /// Die Daten bleiben, wo sie sind — die Kennung aendert sich nicht.
  /// Supabase schickt eine Bestaetigungsmail an [address]; erst mit dem Klick
  /// darin gilt die Adresse und das Konto ist nicht mehr nur geraetegebunden.
  static Future<void> bindEmail(String address, String password) async {
    await _supabase.auth.updateUser(
      UserAttributes(email: address.trim(), password: password),
    );
  }

  static Future<void> setPassword(String password) async {
    await _supabase.auth.updateUser(UserAttributes(password: password));
  }

  /// Meldet an einem bereits hinterlegten Konto an.
  ///
  /// Danach gilt dessen Kennung. Der lokale Zwischenspeicher gehoert dann zum
  /// falschen Konto — der Aufrufer muss ihn neu vom Server laden.
  static Future<void> signInWithPassword(
      String address, String password) async {
    await _supabase.auth
        .signInWithPassword(email: address.trim(), password: password);
  }

  /// Holt den Stand des Kontos vom Server.
  ///
  /// Nach dem Klick in der Bestaetigungsmail weiss die App von sich aus
  /// nicht, dass die Adresse jetzt gilt — das Token in ihrer Hand ist aelter.
  static Future<void> refresh() async {
    await _supabase.auth.refreshSession();
  }

  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Grobe Pruefung gegen Tippfehler. Die Wahrheit sagt der Server.
  static bool looksLikeEmail(String value) {
    final v = value.trim();
    if (v.length < 5 || v.contains(' ')) return false;
    final at = v.indexOf('@');
    // Genau ein @, und davor sowie dahinter muss etwas stehen.
    if (at < 1 || at != v.lastIndexOf('@')) return false;
    final domain = v.substring(at + 1);
    final dot = domain.indexOf('.');
    if (dot < 1 || dot == domain.length - 1) return false;
    return !domain.endsWith('.');
  }

  /// Supabase verlangt mindestens sechs Zeichen.
  static const int minPasswordLength = 6;
}
