import 'package:dio/dio.dart';
import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthResult {
  const AuthResult({this.accessToken, this.requiresEmailConfirmation = false});
  final String? accessToken;
  final bool requiresEmailConfirmation;
}

class AiRequestException implements Exception {
  const AiRequestException(this.code);
  final String code;
}

class SupabaseWebClient {
  SupabaseWebClient._();
  static final instance = SupabaseWebClient._();
  static const _sessionKey = 'finance_ai_access_token';
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AppEnvironmentConfig get _config {
    final config = AppEnvironmentConfig.fromBuild();
    if (!config.hasSupabaseConfiguration) {
      throw StateError('Supabase não configurado para esta versão do aplicativo.');
    }
    return config;
  }

  Future<AuthResult> signIn(String email, String password) async {
    final config = _config;
    final response = await _dio.post<Map<String, dynamic>>(
      '${config.supabaseUrl}/auth/v1/token?grant_type=password',
      data: {'email': email, 'password': password},
      options: Options(headers: {'apikey': config.supabasePublishableKey}),
    );
    final token = response.data?['access_token'] as String?;
    if (token == null) throw StateError('Sessão não retornada.');
    await _storage.write(key: _sessionKey, value: token);
    return AuthResult(accessToken: token);
  }

  Future<AuthResult> signUp(String email, String password) async {
    final config = _config;
    final response = await _dio.post<Map<String, dynamic>>(
      '${config.supabaseUrl}/auth/v1/signup',
      data: {'email': email, 'password': password},
      options: Options(headers: {'apikey': config.supabasePublishableKey}),
    );
    final token = response.data?['access_token'] as String?;
    if (token != null) await _storage.write(key: _sessionKey, value: token);
    return AuthResult(accessToken: token, requiresEmailConfirmation: token == null);
  }

  Future<String?> restoredSession() => _storage.read(key: _sessionKey);
  Future<void> signOut() => _storage.delete(key: _sessionKey);

  Future<Map<String, dynamic>> chat(String token, Map<String, dynamic> body) async {
    final config = _config;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${config.supabaseUrl}/functions/v1/chat',
        data: body,
        options: Options(headers: {'apikey': config.supabasePublishableKey, 'Authorization': 'Bearer $token'}),
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      final data = error.response?.data;
      final errorData = data is Map ? data['error'] : null;
      final code = errorData is Map ? errorData['code'] : null;
      throw AiRequestException(code is String ? code : 'AI_REQUEST_FAILED');
    }
  }
}
