import 'package:finance_ai/app/app.dart';
import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> runFinanceAiApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinanceAiApp());
  final environment = AppEnvironmentConfig.fromBuild();
  if (environment.hasSupabaseConfiguration) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Supabase.initialize(url: environment.supabaseUrl, publishableKey: environment.supabasePublishableKey);
      } catch (_) {
        // A UI permanece disponível; operações protegidas exibem erro tratável.
      }
    });
  }
}
