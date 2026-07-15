import 'package:finance_ai/app/app.dart';
import 'package:flutter/widgets.dart';

Future<void> runFinanceAiApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinanceAiApp());
}
