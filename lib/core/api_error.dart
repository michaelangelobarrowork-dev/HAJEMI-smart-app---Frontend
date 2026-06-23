import 'package:dio/dio.dart';

String formatApiErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is DioException) {
    final responseData = error.response?.data;

    if (responseData is Map<String, dynamic>) {
      final detail = responseData['detail'] ??
          responseData['message'] ??
          responseData['error'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
    } else if (responseData is String && responseData.trim().isNotEmpty) {
      return responseData;
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      final details = _extractDioErrorDetails(error);
      return 'Unable to reach the server (${error.type.name}). $details';
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return 'Your session is invalid or this account is not allowed on this device.';
    }
    if (statusCode == 404) {
      return 'The requested information could not be found.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'The server is currently unavailable. Please try again later.';
    }
  }

  return fallback;
}

String _extractDioErrorDetails(DioException error) {
  final message = error.message?.trim();
  if (message != null && message.isNotEmpty) {
    return message;
  }

  final underlying = error.error;
  if (underlying != null) {
    return underlying.toString();
  }

  return 'Please check your connection and try again.';
}
