import 'package:finance_ai/app/app.dart';
import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> runFinanceAiApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironmentConfig.fromBuild();
  String? initializationError;
  try {
    if (environment.hasSupabaseConfiguration) {
      await Supabase.initialize(
        url: environment.supabaseUrl,
        publishableKey: environment.supabasePublishableKey,
      );
    }
  } catch (_) {
    initializationError = 'A chave pública do Supabase foi recusada ou está indisponível.';
  }
  runApp(FinanceAiApp(initializationError: initializationError));
}
