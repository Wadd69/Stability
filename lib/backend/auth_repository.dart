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

  /// Envoie un email de réinitialisation de mot de passe. [redirectTo] doit
  /// être une URL autorisée dans Authentication > URL Configuration du
  /// projet Supabase (sinon le lien ignore la redirection demandée).
  static Future<void> resetPasswordForEmail(
    String email, {
    String? redirectTo,
  }) async {
    await _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  /// Définit un nouveau mot de passe — n'a de sens qu'avec une session de
  /// récupération active (après avoir cliqué le lien de l'email envoyé par
  /// [resetPasswordForEmail], voir [onAuthStateChange] /
  /// `AuthChangeEvent.passwordRecovery`).
  static Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
