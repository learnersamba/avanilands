/// Build-time settings, passed with `--dart-define-from-file=env/<name>.json`.
abstract final class Env {
  static const name = String.fromEnvironment('APP_ENV', defaultValue: 'local');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const websiteUrl = String.fromEnvironment(
    'WEBSITE_URL',
    defaultValue: 'http://localhost:3100',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
