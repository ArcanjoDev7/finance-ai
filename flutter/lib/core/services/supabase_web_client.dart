import 'package:dio/dio.dart';
import 'package:finance_ai/app/environment/app_environment.dart';

class SupabaseWebClient {
  SupabaseWebClient._();
  static final instance = SupabaseWebClient._();
  final Dio _dio = Dio();

  Future<String> signIn(String email, String password) async {
    final config = AppEnvironmentConfig.fromBuild();
    final response = await _dio.post<Map<String, dynamic>>('${config.supabaseUrl}/auth/v1/token?grant_type=password', data: {'email': email, 'password': password}, options: Options(headers: {'apikey': config.supabasePublishableKey}));
    final token = response.data?['access_token'] as String?;
    if (token == null) throw StateError('Sessão não retornada.');
    return token;
  }

  Future<Map<String, dynamic>> chat(String token, Map<String, dynamic> body) async {
    final config = AppEnvironmentConfig.fromBuild();
    final response = await _dio.post<Map<String, dynamic>>('${config.supabaseUrl}/functions/v1/chat', data: body, options: Options(headers: {'apikey': config.supabasePublishableKey, 'Authorization': 'Bearer $token'}));
    return response.data ?? const {};
  }
}
