import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appEnvironmentProvider = Provider<AppEnvironmentConfig>((ref) {
  throw UnimplementedError('AppEnvironmentConfig must be overridden at startup.');
});

abstract interface class AuthService {}
abstract interface class DatabaseService {}
abstract interface class StorageService {}
abstract interface class ChatAiService {}
abstract interface class QrCodeService {}
abstract interface class NotificationService {}
abstract interface class AnalyticsService {}
