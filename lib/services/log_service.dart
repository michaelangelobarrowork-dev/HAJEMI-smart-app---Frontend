import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/log_model.dart';
import 'dio_client.dart';

final logServiceProvider = Provider<LogService>((ref) => LogService(
      dio: ref.watch(dioProvider),
    ));

class LogService {
  final Dio _dio;

  LogService({required Dio dio}) : _dio = dio;

  Future<List<LogModel>> getLogs() async {
    final res = await _dio.get(ApiConstants.logs);
    final data = res.data;

    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(LogModel.fromJson)
          .toList();
    }

    if (data is Map<String, dynamic> && data['results'] is List) {
      return (data['results'] as List)
          .whereType<Map<String, dynamic>>()
          .map(LogModel.fromJson)
          .toList();
    }

    return const [];
  }
}
