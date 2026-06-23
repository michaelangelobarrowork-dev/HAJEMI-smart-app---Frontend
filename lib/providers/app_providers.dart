import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_model.dart';
import '../models/household_model.dart';
import '../models/log_model.dart';
import '../models/user_model.dart';
import '../models/detection_model.dart';
import '../services/device_service.dart';
import '../services/log_service.dart';
import '../services/user_service.dart';

final devicesProvider = FutureProvider.autoDispose<List<DeviceModel>>((ref) {
  return ref.watch(deviceServiceProvider).getDevices();
});

final deviceProvider = FutureProvider.autoDispose.family<DeviceModel, int>((ref, id) {
  return ref.watch(deviceServiceProvider).getDevice(id);
});

final gateDetectionsProvider = FutureProvider.autoDispose.family<List<DetectionModel>, int>((ref, id) async {
  final data = await ref.watch(deviceServiceProvider).getGateDetections(id);
  return data.map((e) => DetectionModel.fromJson(e as Map<String, dynamic>)).toList();
});

final roomDetectionsProvider = FutureProvider.autoDispose.family<List<DetectionModel>, int>((ref, id) async {
  final data = await ref.watch(deviceServiceProvider).getRoomDetections(id);
  return data.map((e) => DetectionModel.fromJson(e as Map<String, dynamic>)).toList();
});

final currentUserProvider = FutureProvider.autoDispose<UserModel>((ref) {
  return ref.watch(userServiceProvider).getMe();
});

final householdProvider = FutureProvider.autoDispose<HouseholdModel?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user.householdId == null) return null;
  return ref.watch(userServiceProvider).getHousehold(user.householdId!);
});

// ── Activity Logs Filtering ──────────────────────────────────────────────────

class LogFilters {
  final String? deviceId;
  final DateTimeRange? dateRange;
  final String? actionType;

  const LogFilters({
    this.deviceId = 'all',
    this.dateRange,
    this.actionType = 'all',
  });

  LogFilters copyWith({
    String? deviceId,
    DateTimeRange? dateRange,
    String? actionType,
  }) {
    return LogFilters(
      deviceId: deviceId ?? this.deviceId,
      dateRange: dateRange ?? this.dateRange,
      actionType: actionType ?? this.actionType,
    );
  }
}

final logFiltersProvider = StateProvider<LogFilters>((ref) => const LogFilters());

final activityLogsProvider = FutureProvider.autoDispose<List<LogModel>>((ref) {
  final filters = ref.watch(logFiltersProvider);
  return ref.watch(logServiceProvider).getLogs(
    deviceId: filters.deviceId,
    from: filters.dateRange?.start.toIso8601String(),
    to: filters.dateRange?.end.toIso8601String(),
    actionType: filters.actionType,
  );
});
