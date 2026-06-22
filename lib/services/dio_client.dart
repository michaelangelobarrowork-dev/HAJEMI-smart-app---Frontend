import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);

  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.read(key: StorageKeys.accessToken);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        try {
          final refreshToken =
              await storage.read(key: StorageKeys.refreshToken);
          if (refreshToken != null) {
            final res = await Dio().post(
              '${ApiConstants.baseUrl}${ApiConstants.refresh}',
              data: {'refresh_token': refreshToken},
            );
            final newAccess  = res.data['access_token']  as String;
            final newRefresh = res.data['refresh_token'] as String;
            await storage.write(
                key: StorageKeys.accessToken, value: newAccess);
            await storage.write(
                key: StorageKeys.refreshToken, value: newRefresh);
            error.requestOptions.headers['Authorization'] =
                'Bearer $newAccess';
            return handler
                .resolve(await dio.fetch(error.requestOptions));
          }
        } catch (_) {
          await storage.deleteAll();
        }
      }
      handler.next(error);
    },
  ));

  return dio;
});
