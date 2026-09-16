/// Identifiants du projet Supabase. La clé "anon" est conçue pour être
/// publique (embarquée dans le client) — la sécurité réelle vient des
/// règles RLS (Row Level Security) définies côté base de données, pas
/// du secret de cette clé.
class SupabaseConfig {
  static const String url = 'https://wrxesblupqvekzgzozle.supabase.co';
  static const String anonKey =
      'sb_publishable_DLj-PcFE13gg8jP1T82-fg_VR2z49q4';

  /// URL vers laquelle rediriger après un lien d'authentification par
  /// email (réinitialisation de mot de passe ou confirmation de
  /// création de compte) — doit être ajoutée aux "Redirect URLs"
  /// autorisées dans Authentication > URL Configuration du dashboard
  /// Supabase, sinon le lien ignore cette redirection et retombe sur le
  /// "Site URL" par défaut du projet. Pointe vers la PWA (fonctionne
  /// aussi pour les utilisateurs de l'app mobile : le lien s'ouvre dans
  /// le navigateur, l'action se termine là, puis ils reviennent dans
  /// l'app).
  static const String authRedirectUrl = 'https://wadd69.github.io/Stability/';
}
