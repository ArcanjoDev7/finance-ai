enum AppEnvironment { development, homolog, production }

class AppEnvironmentConfig {
  const AppEnvironmentConfig._({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  factory AppEnvironmentConfig.fromBuild() {
    const environmentName = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
    return AppEnvironmentConfig._(
      environment: switch (environmentName) {
        'production' => AppEnvironment.production,
        'homolog' => AppEnvironment.homolog,
        _ => AppEnvironment.development,
      },
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    );
  }

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get hasSupabaseConfiguration =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
