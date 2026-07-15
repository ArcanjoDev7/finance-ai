import 'package:finance_ai/app/app.dart';
import 'package:finance_ai/app/startup/supabase_bootstrap.dart';
import 'package:flutter/widgets.dart';

Future<void> runFinanceAiApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseBootstrap.error = 'A conexão com o Supabase está em manutenção; o Dashboard continua disponível.';
  runApp(const FinanceAiApp());
}
