import 'dart:async';

import 'package:finance_ai/app/app.dart';
import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:finance_ai/core/logger/app_logger.dart';
import 'package:finance_ai/core/services/service_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> runFinanceAiApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironmentConfig.fromBuild();
  final logger = AppLogger();

  FlutterError.onError = (details) {
    logger.error('Flutter framework error', details.exception, details.stack);
  };

  await runZonedGuarded(() async {
    if (environment.hasSupabaseConfiguration) {
      await Supabase.initialize(
        url: environment.supabaseUrl,
        publishableKey: environment.supabasePublishableKey,
      );
    } else {
      logger.warning('Supabase was not initialized: build defines are missing.');
    }

    runApp(
      ProviderScope(
        overrides: [appEnvironmentProvider.overrideWithValue(environment)],
        observers: [RiverpodLoggerObserver(logger)],
        child: const FinanceAiApp(),
      ),
    );
  }, (error, stackTrace) => logger.error('Uncaught asynchronous error', error, stackTrace));
}
