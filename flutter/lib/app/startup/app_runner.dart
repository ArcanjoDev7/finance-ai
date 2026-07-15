import 'package:finance_ai/app/app.dart';
import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:finance_ai/app/startup/supabase_bootstrap.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> runFinanceAiApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  PlatformDispatcher.instance.onError = (error, _) {
    SupabaseBootstrap.error = 'Falha do Supabase: ${error.runtimeType}';
    return true;
  };
  runApp(const FinanceAiApp());
  final environment = AppEnvironmentConfig.fromBuild();
  if (!environment.hasSupabaseConfiguration) {
    SupabaseBootstrap.error = 'As variáveis públicas do Supabase não foram encontradas.';
    return;
  }
  try {
    await Supabase.initialize(url: environment.supabaseUrl, publishableKey: environment.supabasePublishableKey);
    SupabaseBootstrap.ready = true;
  } catch (error) {
    SupabaseBootstrap.error = 'Falha ao conectar ao Supabase: ${error.runtimeType}';
  }
}
