import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:finance_ai/app/environment/app_environment.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthResult {
  const AuthResult({
    this.accessToken,
    this.refreshToken,
    this.requiresEmailConfirmation = false,
  });
  final String? accessToken;
  final String? refreshToken;
  final bool requiresEmailConfirmation;
}

class AiRequestException implements Exception {
  const AiRequestException(
    this.code, {
    this.providerStatus,
    this.providerCode,
    this.providerMessage,
    this.providerModels,
  });
  final String code;
  final int? providerStatus;
  final String? providerCode;
  final String? providerMessage;
  final List<String>? providerModels;
}

class SupabaseWebClient {
  SupabaseWebClient._();
  static final instance = SupabaseWebClient._();
  static const _sessionKey = 'finance_ai_access_token';
  static const _refreshTokenKey = 'finance_ai_refresh_token';
  static const _profileNameKey = 'finance_ai_profile_name';
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AppEnvironmentConfig get _config {
    final config = AppEnvironmentConfig.fromBuild();
    if (!config.hasSupabaseConfiguration) {
      throw StateError(
        'Supabase não configurado para esta versão do aplicativo.',
      );
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
    return _persistAuthSession(response.data);
  }

  Future<AuthResult> signUp(String email, String password) async {
    final config = _config;
    final response = await _dio.post<Map<String, dynamic>>(
      '${config.supabaseUrl}/auth/v1/signup',
      data: {'email': email, 'password': password},
      options: Options(headers: {'apikey': config.supabasePublishableKey}),
    );
    final token = response.data?['access_token'] as String?;
    if (token == null) return const AuthResult(requiresEmailConfirmation: true);
    return _persistAuthSession(response.data);
  }

  Future<AuthResult> _persistAuthSession(Map<String, dynamic>? payload) async {
    final accessToken = payload?['access_token'] as String?;
    final refreshToken = payload?['refresh_token'] as String?;
    if (accessToken == null || refreshToken == null) {
      throw StateError('Sessão não retornada.');
    }
    await _storage.write(key: _sessionKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    return AuthResult(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<String?> restoredSession() async {
    final accessToken = await _storage.read(key: _sessionKey);
    if (accessToken == null) return null;
    if (!_expiresSoon(accessToken)) return accessToken;
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) {
      await signOut();
      return null;
    }
    try {
      final config = _config;
      final response = await _dio.post<Map<String, dynamic>>(
        '${config.supabaseUrl}/auth/v1/token?grant_type=refresh_token',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'apikey': config.supabasePublishableKey}),
      );
      return (await _persistAuthSession(response.data)).accessToken;
    } catch (_) {
      await signOut();
      return null;
    }
  }

  bool _expiresSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final expiresAt = payload is Map && payload['exp'] is num
          ? (payload['exp'] as num).toInt()
          : 0;
      return DateTime.now().isAfter(
        DateTime.fromMillisecondsSinceEpoch((expiresAt - 60) * 1000),
      );
    } catch (_) {
      return true;
    }
  }

  Future<void> signOut() async {
    final accessToken = await _storage.read(key: _sessionKey);
    final config = AppEnvironmentConfig.fromBuild();

    try {
      if (accessToken != null && config.hasSupabaseConfiguration) {
        await _dio.post<void>(
          '${config.supabaseUrl}/auth/v1/logout',
          options: Options(
            headers: {
              'apikey': config.supabasePublishableKey,
              'Authorization': 'Bearer $accessToken',
            },
          ),
        );
      }
    } catch (_) {
      // Local sign-out must still succeed when the network is unavailable.
    } finally {
      await _storage.delete(key: _sessionKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _profileNameKey);
      await clearLocalDashboard();
    }
  }

  Future<String?> loadCachedProfileName() =>
      _storage.read(key: _profileNameKey);

  Future<String?> loadProfileName(String token) async {
    final config = _config;
    final response = await _dio.get<List<dynamic>>(
      '${config.supabaseUrl}/rest/v1/profiles',
      queryParameters: {'select': 'full_name', 'deleted_at': 'is.null'},
      options: Options(
        headers: {
          'apikey': config.supabasePublishableKey,
          'Authorization': 'Bearer $token',
        },
      ),
    );
    final names =
        response.data
            ?.whereType<Map>()
            .map((item) => item['full_name'])
            .whereType<String>()
            .toList() ??
        const <String>[];
    final name = names.isEmpty ? null : names.first;
    if (name != null && name.trim().isNotEmpty) {
      await _storage.write(key: _profileNameKey, value: name.trim());
    }
    return name?.trim();
  }

  Future<void> saveProfileName(String name, {String? token}) async {
    final normalized = name.trim();
    await _storage.write(key: _profileNameKey, value: normalized);
    if (token == null) return;
    final config = _config;
    await _dio.patch<void>(
      '${config.supabaseUrl}/rest/v1/profiles',
      queryParameters: {'deleted_at': 'is.null'},
      data: {'full_name': normalized},
      options: Options(
        headers: {
          'apikey': config.supabasePublishableKey,
          'Authorization': 'Bearer $token',
          'Prefer': 'return=minimal',
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> loadTimeline(String token) async {
    final config = _config;
    final response = await _dio.get<List<dynamic>>(
      '${config.supabaseUrl}/rest/v1/transactions',
      queryParameters: {
        'select':
            'id,description,amount_minor,transaction_type,occurred_at,metadata',
        'order': 'occurred_at.desc',
        'deleted_at': 'is.null',
      },
      options: Options(
        headers: {
          'apikey': config.supabasePublishableKey,
          'Authorization': 'Bearer $token',
        },
      ),
    );
    return (response.data ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>?> loadLocalDashboard() async {
    final value = await _storage.read(key: 'finance_ai_dashboard_draft');
    if (value == null) return null;
    final decoded = jsonDecode(value);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  Future<void> saveLocalDashboard(Map<String, dynamic> value) => _storage.write(
    key: 'finance_ai_dashboard_draft',
    value: jsonEncode(value),
  );

  Future<void> clearLocalDashboard() =>
      _storage.delete(key: 'finance_ai_dashboard_draft');

  Future<Map<String, dynamic>> resetAccount(
    String token,
    String idempotencyKey,
  ) => chat(token, {
    'message': 'Confirmo que quero zerar a conta.',
    'operation': 'reset_account',
    'idempotencyKey': idempotencyKey,
  });

  Future<Map<String, dynamic>> chat(
    String token,
    Map<String, dynamic> body,
  ) async {
    final config = _config;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${config.supabaseUrl}/functions/v1/chat',
        data: body,
        options: Options(
          headers: {
            'apikey': config.supabasePublishableKey,
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      final data = error.response?.data;
      final errorData = data is Map ? data['error'] : null;
      final code = errorData is Map ? errorData['code'] : null;
      final providerStatus =
          errorData is Map && errorData['providerStatus'] is num
          ? (errorData['providerStatus'] as num).toInt()
          : error.response?.statusCode;
      final providerCode =
          errorData is Map && errorData['providerCode'] is String
          ? errorData['providerCode'] as String
          : error.type.name;
      final providerMessage =
          errorData is Map && errorData['providerMessage'] is String
          ? errorData['providerMessage'] as String
          : null;
      final providerModels =
          errorData is Map && errorData['providerModels'] is List
          ? (errorData['providerModels'] as List).whereType<String>().toList()
          : null;
      throw AiRequestException(
        code is String ? code : 'AI_REQUEST_FAILED',
        providerStatus: providerStatus,
        providerCode: providerCode,
        providerMessage: providerMessage,
        providerModels: providerModels,
      );
    }
  }
}
