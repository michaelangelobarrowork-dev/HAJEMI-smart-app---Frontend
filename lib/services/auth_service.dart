import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';
import 'dio_client.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService(
      dio: ref.watch(dioProvider),
      storage: ref.watch(secureStorageProvider),
    ));

class AuthService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthService({required Dio dio, required FlutterSecureStorage storage})
      : _dio = dio,
        _storage = storage;

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: StorageKeys.accessToken);
    if (token == null || token.isEmpty) {
      await _storage.deleteAll();
      return false;
    }

    if (_isExpiredToken(token)) {
      await _storage.deleteAll();
      return false;
    }

    return true;
  }

  bool _isExpiredToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return true;
    }

    try {
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = json['exp'];

      if (exp is int) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(
          exp * 1000,
          isUtc: true,
        );
        return expiry.isBefore(DateTime.now().toUtc());
      }
    } catch (_) {
      return true;
    }

    return false;
  }

  /// Register a new account. Throws [DioException] on failure.
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    await _dio.post(ApiConstants.register, data: {
      'username': username,
      'email': email,
      'password': password,
      'confirm_password': confirmPassword,
    });
  }

  /// Verify email OTP. Throws [DioException] on failure.
  Future<void> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    await _dio.post(ApiConstants.verifyOtp, data: {
      'email': email,
      'otp_code': otpCode,
    });
  }

  /// Resend OTP email. Throws [DioException] on failure.
  Future<void> resendOtp({required String email}) async {
    await _dio.post(ApiConstants.resendOtp, data: {'email': email});
  }

  /// Login and persist tokens. Throws [DioException] on failure.
  Future<void> login({
    required String identifier,
    required String password,
    bool rememberMe = false,
  }) async {
    final res = await _dio.post(ApiConstants.login, data: {
      'identifier': identifier,
      'password': password,
      'remember_me': rememberMe,
    });
    await _storage.write(
        key: StorageKeys.accessToken,
        value: res.data['access_token'] as String);
    await _storage.write(
        key: StorageKeys.refreshToken,
        value: res.data['refresh_token'] as String);
  }

  /// Logout and clear stored tokens.
  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.logout);
    } finally {
      await _storage.deleteAll();
    }
  }
}
