import 'package:finance_ai/app/theme/app_theme.dart';
import 'package:finance_ai/features/dashboard/presentation/pages/dashboard_preview_page.dart';
import 'package:flutter/material.dart';

class FinanceAiApp extends StatelessWidget {
  const FinanceAiApp({super.key});

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
