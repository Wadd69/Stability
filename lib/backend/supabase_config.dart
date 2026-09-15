/// Identifiants du projet Supabase. La clé "anon" est conçue pour être
/// publique (embarquée dans le client) — la sécurité réelle vient des
/// règles RLS (Row Level Security) définies côté base de données, pas
/// du secret de cette clé.
class SupabaseConfig {
  static const String url = 'https://wrxesblupqvekzgzozle.supabase.co';
  static const String anonKey =
      'sb_publishable_DLj-PcFE13gg8jP1T82-fg_VR2z49q4';

  /// URL vers laquelle rediriger après un lien de réinitialisation de mot
  /// de passe — doit être ajoutée aux "Redirect URLs" autorisées dans
  /// Authentication > URL Configuration du dashboard Supabase, sinon le
  /// lien ignore cette redirection. Pointe vers la PWA (fonctionne aussi
  /// pour les utilisateurs de l'app mobile : le lien s'ouvre dans le
  /// navigateur, le mot de passe est changé là, puis ils se reconnectent
  /// dans l'app avec le nouveau mot de passe).
  static const String passwordResetRedirectUrl =
      'https://wadd69.github.io/Stability/';
}
