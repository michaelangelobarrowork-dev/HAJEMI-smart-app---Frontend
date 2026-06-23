import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../models/household_model.dart';
import 'dio_client.dart';

final userServiceProvider = Provider<UserService>((ref) => UserService(
      dio: ref.watch(dioProvider),
    ));

class UserService {
  final Dio _dio;

  UserService({required Dio dio}) : _dio = dio;

  Future<UserModel> getMe() async {
    final res = await _dio.get(ApiConstants.me);
    return UserModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> updateUsername(String username) async {
    await _dio.patch(ApiConstants.updateUsername, data: {'username': username});
  }

  Future<void> updateEmail(String email) async {
    await _dio.patch(ApiConstants.updateEmail, data: {'email': email});
  }

  Future<void> updatePassword(String currentPassword, String newPassword) async {
    await _dio.patch(ApiConstants.updatePassword, data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<void> registerFcmToken(String token) async {
    await _dio.post(ApiConstants.registerFcmToken, data: {'fcm_token': token});
  }

  Future<HouseholdModel> getHousehold(int id) async {
    final res = await _dio.get('${ApiConstants.household}/$id');
    final householdMap = res.data as Map<String, dynamic>;

    if (householdMap['members'] == null || (householdMap['members'] as List).isEmpty) {
      try {
        final membersRes = await _dio.get('${ApiConstants.household}/$id/members');
        householdMap['members'] = membersRes.data;
      } catch (e) {
        print('[UserService] Failed to fetch members: $e');
      }
    }

    return HouseholdModel.fromJson(householdMap);
  }
}
