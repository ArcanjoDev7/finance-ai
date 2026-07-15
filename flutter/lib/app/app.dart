import 'package:finance_ai/app/theme/app_theme.dart';
import 'package:finance_ai/features/dashboard/presentation/pages/dashboard_preview_page.dart';
import 'package:flutter/material.dart';

class FinanceAiApp extends StatelessWidget {
  const FinanceAiApp({super.key, this.initializationError});

  final String? initializationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const DashboardPreviewPage(),
    );
  }
}

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48), const SizedBox(height: 16), Text('Não foi possível conectar ao Finance AI', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 10), const Text('Verifique a configuração pública do Supabase e atualize a página.', textAlign: TextAlign.center), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)]))),
          ),
        ),
      );
}
