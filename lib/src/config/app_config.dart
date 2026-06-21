/// Application configuration sourced from compile-time environment values.
///
/// Values are injected at build/run time via `--dart-define-from-file=env.json`
/// (see `env.example.json`). Secrets such as the Supabase **secret key** are
/// NEVER referenced here — only the public **publishable key** is used by the
/// client app. Server-only secrets live in Supabase Edge Function secrets.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase modern *publishable* key (`sb_publishable_...`). Safe for clients.
  static const String supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Throws if required configuration is missing so misconfiguration fails fast
  /// at startup rather than producing confusing network errors later.
  static void validate() {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required config: ${missing.join(', ')}. '
        'Run with: flutter run --dart-define-from-file=env.json',
      );
    }
  }
}
