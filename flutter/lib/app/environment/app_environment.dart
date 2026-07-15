enum AppEnvironment { development, homolog, production }

const _environmentName = String.fromEnvironment(
  'ENVIRONMENT',
  defaultValue: 'development',
);
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

class AppEnvironmentConfig {
  const AppEnvironmentConfig._({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  factory AppEnvironmentConfig.fromBuild() {
    return AppEnvironmentConfig._(
      environment: switch (_environmentName) {
        'production' => AppEnvironment.production,
        'homolog' => AppEnvironment.homolog,
        _ => AppEnvironment.development,
      },
      supabaseUrl: _supabaseUrl,
      supabasePublishableKey: _supabasePublishableKey,
    );
  }

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get hasSupabaseConfiguration =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
