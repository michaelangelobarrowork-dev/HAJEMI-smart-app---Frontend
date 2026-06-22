import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajemi/core/api_error.dart';

void main() {
  group('formatApiErrorMessage', () {
    test('uses a friendly message for connection errors', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/login'),
        type: DioExceptionType.connectionError,
      );

      expect(
        formatApiErrorMessage(error),
        'Please check your internet connection and try again.',
      );
    });

    test('prefers backend detail messages when available', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/login'),
          statusCode: 401,
          data: {'detail': 'This account is not allowed on this device.'},
        ),
      );

      expect(
        formatApiErrorMessage(error),
        'This account is not allowed on this device.',
      );
    });
  });
}
