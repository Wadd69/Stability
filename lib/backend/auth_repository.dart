import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Encapsule l'authentification Supabase (email + mot de passe).
class AuthRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  static Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  /// Vrai dès qu'une session de récupération de mot de passe est détectée
  /// (lien cliqué dans l'email envoyé par [resetPasswordForEmail]). Doit
  /// être écouté dès `main()`, juste après `Supabase.initialize` — c'est à
  /// ce moment que le SDK détecte le lien dans l'URL (web) et émet
  /// l'évènement, potentiellement bien avant qu'un widget n'ait eu la
  /// chance de s'abonner au flux (l'écran de lancement peut encore
  /// tourner plusieurs secondes) ; s'abonner plus tard raterait
  /// l'évènement, un `Stream` broadcast ne le rejouant pas.
  static final ValueNotifier<bool> isPasswordRecovery = ValueNotifier(false);

  /// Vrai juste après avoir cliqué le lien de confirmation d'un nouveau
  /// compte — contrairement à [isPasswordRecovery], il n'y a pas
  /// d'`AuthChangeEvent` dédié pour ce cas (c'est un `signedIn` comme un
  /// autre) : on se base directement sur `type=signup` dans l'URL (web).
  static final ValueNotifier<bool> isEmailJustConfirmed = ValueNotifier(false);

  static void startListeningForPasswordRecovery() {
    onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        isPasswordRecovery.value = true;
      }
    });
  }

  static Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: SupabaseConfig.authRedirectUrl,
    );
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

  /// Supprime définitivement le compte de connexion (et, par cascade côté
  /// base de données, les lignes qui en dépendent : profil, appartenance
  /// aux comptes partagés, etc.) — appelle la fonction Postgres
  /// `delete_own_account`, à créer côté Supabase (SQL fourni dans
  /// l'aide de l'écran "Compte & sécurité") : une suppression aussi
  /// sensible ne doit jamais passer par une clé cliente élevée, seulement
  /// par une fonction serveur restreinte à `auth.uid()`.
  static Future<void> deleteOwnAccount() async {
    await _client.rpc('delete_own_account');
    await signOut();
  }
}

/// Traduit une erreur d'authentification en message lisible côté écran, à
/// la place du texte technique brut de l'exception (ex: "Invalid login
/// credentials" → "Email ou mot de passe incorrect."). Les codes viennent
/// de https://supabase.com/docs/guides/auth/debugging/error-codes — ceux
/// non listés ici retombent sur le message générique de Supabase, déjà
/// écrit pour un humain côté serveur.
String friendlyAuthErrorMessage(Object error) {
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'Email ou mot de passe incorrect.';
      case 'email_not_confirmed':
        return 'Confirmez votre email avant de vous connecter '
            '(vérifiez vos spams).';
      case 'user_already_exists':
      case 'email_exists':
        return 'Un compte existe déjà avec cet email.';
      case 'user_not_found':
        return 'Aucun compte ne correspond à cet email.';
      case 'weak_password':
        return 'Mot de passe trop faible : choisissez-en un plus long ou '
            'plus complexe.';
      case 'same_password':
        return 'Le nouveau mot de passe doit être différent de l\'ancien.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
    }

    if (error is AuthRetryableFetchException ||
        error.message.contains('SocketException') ||
        error.message.contains('Failed host lookup')) {
      return 'Impossible de contacter le serveur. Vérifiez votre '
          'connexion internet.';
    }

    return error.message;
  }

  return 'Une erreur est survenue. Réessayez.';
}
