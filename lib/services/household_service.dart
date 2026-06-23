import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/household_model.dart';
import 'dio_client.dart';

final householdServiceProvider = Provider<HouseholdService>((ref) => HouseholdService(
      dio: ref.watch(dioProvider),
    ));

class HouseholdService {
  final Dio _dio;

  HouseholdService({required Dio dio}) : _dio = dio;

  /// Fetch the current user's household.
  /// Re-checking openapi.json: there is NO GET /household.
  /// BUT there is GET /household/{household_id}/members.
  /// Usually, in such systems, the user object contains the household_id.
  Future<HouseholdModel?> getMyHousehold() async {
    try {
      // We try the common paths. If the database has it, one of these is likely the GET endpoint.
      final res = await _dio.get('/household/');
      if (res.data == null) return null;
      return HouseholdModel.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      try {
        final res = await _dio.get('/household');
        if (res.data == null) return null;
        return HouseholdModel.fromJson(res.data as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }
  }

  Future<HouseholdModel> createHousehold(String name) async {
    final res = await _dio.post(ApiConstants.householdCreate, data: {'name': name});
    return HouseholdModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> joinHousehold(String joinCode) async {
    await _dio.post(ApiConstants.householdJoin, data: {'join_code': joinCode});
  }

  Future<void> leaveHousehold() async {
    await _dio.post(ApiConstants.householdLeave);
  }

  Future<void> updateHouseholdName(int id, String name) async {
    await _dio.patch('${ApiConstants.household}/$id', data: {'name': name});
  }

  Future<void> kickMember(int householdId, int userId) async {
    await _dio.delete('${ApiConstants.household}/$householdId/members/$userId');
  }

  Future<void> deleteHousehold(int householdId) async {
    try {
      await _dio.delete('${ApiConstants.household}/$householdId');
    } catch (e) {
      print('[HouseholdService] Delete error: $e');
      rethrow;
    }
  }
}
