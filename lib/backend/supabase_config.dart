/// Identifiants du projet Supabase. La clé "anon" est conçue pour être
/// publique (embarquée dans le client) — la sécurité réelle vient des
/// règles RLS (Row Level Security) définies côté base de données, pas
/// du secret de cette clé.
class SupabaseConfig {
  static const String url = 'https://wrxesblupqvekzgzozle.supabase.co';
  static const String anonKey = 'sb_publishable_DLj-PcFE13gg8jP1T82-fg_VR2z49q4';
}
