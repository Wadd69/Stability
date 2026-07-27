import 'package:supabase_flutter/supabase_flutter.dart';

/// Encapsule l'authentification Supabase (email + mot de passe).
class AuthRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  static Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  static Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(email: email, password: password);
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
