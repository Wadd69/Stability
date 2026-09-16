/// Identifiant du projet Sentry (remontée de crash). Comme la clé "anon"
/// Supabase, un DSN Sentry est conçu pour être public — il ne permet que
/// d'envoyer des évènements à ce projet, jamais de les lire.
class SentryConfig {
  static const String dsn =
      'https://8e3d9d8431ef4a4414c32fdfb438d07a@o4512094677237760.ingest.de.sentry.io/4512094686609488';
}
