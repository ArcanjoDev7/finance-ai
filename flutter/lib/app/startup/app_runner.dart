import 'package:finance_ai/app/app.dart';
import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> runFinanceAiApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironmentConfig.fromBuild();
  if (environment.hasSupabaseConfiguration) {
    await Supabase.initialize(
      url: environment.supabaseUrl,
      publishableKey: environment.supabasePublishableKey,
    );
  }
  runApp(const FinanceAiApp());
}
