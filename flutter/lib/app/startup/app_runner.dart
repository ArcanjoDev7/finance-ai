import 'package:finance_ai/app/app.dart';
import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:finance_ai/app/startup/supabase_bootstrap.dart';
import 'package:flutter/widgets.dart';

Future<void> runFinanceAiApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironmentConfig.fromBuild();
  SupabaseBootstrap.ready = environment.hasSupabaseConfiguration;
  SupabaseBootstrap.error = environment.hasSupabaseConfiguration ? null : 'Variáveis públicas do Supabase não encontradas.';
  runApp(const FinanceAiApp());
}
