import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();
  static const _uuid = Uuid();

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.backendBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: AppConstants.jwtTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['X-Device-Id'] = await getOrCreateDeviceId();
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  static bool isConnectivityError(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return true;
      }

      final innerError = error.error;
      if (innerError is SocketException) {
        return true;
      }

      final message = (error.message ?? innerError?.toString() ?? '').toLowerCase();
      return message.contains('connection error') ||
          message.contains('failed host lookup') ||
          message.contains('network is unreachable') ||
          message.contains('timed out') ||
          message.contains('connection aborted');
    }

    if (error is SocketException) {
      return true;
    }

    return false;
  }

  static String userFriendlyError(
    Object error, {
    required String language,
    String? fallbackPt,
    String? fallbackEn,
  }) {
    final isPT = language == 'pt';

    if (isConnectivityError(error)) {
      return isPT
          ? 'Sem ligação à internet. Verifica a tua conexão e tenta novamente.'
          : 'No internet connection. Check your connection and try again.';
    }

    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    }

    return isPT
        ? (fallbackPt ?? 'Ocorreu um erro. Tenta novamente.')
        : (fallbackEn ?? 'Something went wrong. Please try again.');
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(AppConstants.deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final deviceId = _uuid.v4();
    await prefs.setString(AppConstants.deviceIdKey, deviceId);
    return deviceId;
  }

  // Auth
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? name,
    String language = 'pt',
  }) async {
    try {
      final res = await _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'name': name ?? '',
          'language': language,
        },
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (error) {
      throw Exception(userFriendlyError(error, language: language));
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String language = 'pt',
  }) async {
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (error) {
      throw Exception(userFriendlyError(error, language: language));
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _dio.get('/auth/me');
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteAccount() async {
    await _dio.delete('/auth/me');
  }

  // Sermons
  Future<Map<String, dynamic>> getSermons({String? query, int page = 1}) async {
    try {
      final res = await _dio.get(
        '/sermons',
        queryParameters: {
          if (query != null && query.isNotEmpty) 'q': query,
          'page': page,
        },
      );
      return res.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> saveSermon(Map<String, dynamic> data) async {
    final res = await _dio.post('/sermons', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteSermon(String id) async {
    await _dio.delete('/sermons/$id');
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: AppConstants.jwtTokenKey, value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: AppConstants.jwtTokenKey);
  }

  Future<String?> getToken() async {
    return _storage.read(key: AppConstants.jwtTokenKey);
  }
}
