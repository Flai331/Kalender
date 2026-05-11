import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  static User? get currentUser => _supabase.auth.currentUser;
  static String? get userId => _supabase.auth.currentUser?.id;

  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

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

  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
