import 'package:finance_ai/app/app.dart';
import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:finance_ai/app/startup/supabase_bootstrap.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> runFinanceAiApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironmentConfig.fromBuild();
  try {
    if (environment.hasSupabaseConfiguration) {
      await Supabase.initialize(url: environment.supabaseUrl, publishableKey: environment.supabasePublishableKey);
      SupabaseBootstrap.ready = true;
    } else {
      SupabaseBootstrap.error = 'As variáveis públicas do Supabase não foram encontradas.';
    }
  } catch (_) {
    SupabaseBootstrap.error = 'Não foi possível iniciar a conexão segura com o Supabase.';
  }
  runApp(const FinanceAiApp());
}
