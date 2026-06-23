import 'package:dio/dio.dart';

/// Formats error objects into user-friendly messages.
String formatApiErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is DioException) {
    // Connection and Timeout issues
    if (error.type == DioExceptionType.connectionError) {
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('socketexception') || errorStr.contains('connection refused')) {
        return 'Unable to connect to the server.';
      }
      return 'No internet connection.';
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'The request took too long. Please try again.';
    }

    final statusCode = error.response?.statusCode;

    // Handle specific status codes
    if (statusCode == 401 || statusCode == 403) {
      return 'Session expired or access denied. Please log in again.';
    }

    if (statusCode == 404) {
      return 'Unable to load data. Please try again.';
    }

    if (statusCode != null && statusCode >= 500) {
      return 'Server is currently unavailable.';
    }

    // Try to extract backend detail if it's a 400-level error (usually validation/logic)
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final detail = responseData['detail'] ??
          responseData['message'] ??
          responseData['error'];

      if (detail is String && detail.trim().isNotEmpty) {
        // Avoid technical messages
        final lowerDetail = detail.toLowerCase();
        if (lowerDetail.contains('exception') ||
            lowerDetail.contains('stack') ||
            lowerDetail.contains('trace') ||
            lowerDetail.contains('line ') ||
            lowerDetail.contains('sql')) {
          return 'Something went wrong. Please try again later.';
        }
        return detail;
      }
    }
  }

  // Handle generic SocketException if Dio didn't wrap it or if it's a raw exception
  final errorStr = error.toString().toLowerCase();
  if (errorStr.contains('socketexception') || errorStr.contains('connection refused')) {
    return 'Unable to connect to the server.';
  }

  if (errorStr.contains('network_error') || errorStr.contains('no internet')) {
    return 'No internet connection.';
  }

  return fallback;
}
