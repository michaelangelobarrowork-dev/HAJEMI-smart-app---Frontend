import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/device_model.dart';
import 'dio_client.dart';

final deviceServiceProvider = Provider<DeviceService>((ref) => DeviceService(
      dio: ref.watch(dioProvider),
    ));

class DeviceService {
  final Dio _dio;

  DeviceService({required Dio dio}) : _dio = dio;

  /// Fetch all devices for the authenticated user.
  Future<List<DeviceModel>> getDevices() async {
    final res = await _dio.get(ApiConstants.devices);
    final list = res.data as List<dynamic>;
    return list
        .map((e) => DeviceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single device by ID.
  Future<DeviceModel> getDevice(int deviceId) async {
    final res = await _dio.get('${ApiConstants.devices}/$deviceId');
    return DeviceModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Register a new device via product key + name.
  Future<void> registerDevice({
    required String productKey,
    required String deviceName,
  }) async {
    await _dio.post(ApiConstants.devicesRegister, data: {
      'product_key': productKey,
      'device_name': deviceName,
    });
  }

  /// Update device name.
  Future<void> updateDeviceName({
    required int deviceId,
    required String deviceName,
  }) async {
    await _dio.patch('${ApiConstants.devices}/$deviceId', data: {
      'device_name': deviceName,
    });
  }

  /// Delete / unregister a device.
  Future<void> unregisterDevice(int deviceId) async {
    await _dio.delete('${ApiConstants.devices}/$deviceId');
  }

  /// Toggle auto-mode on the night light.
  Future<void> toggleAutoMode({
    required int deviceId,
    required bool autoMode,
  }) async {
    await _dio.patch(
      '${ApiConstants.devices}/$deviceId/night-light/auto-mode',
      data: {'auto_mode': autoMode},
    );
  }

  /// Toggle a specific LED.
  Future<void> toggleLed({
    required int deviceId,
    required int ledNumber,
    required bool state,
  }) async {
    await _dio.patch(
      '${ApiConstants.devices}/$deviceId/night-light/leds/$ledNumber',
      data: {'state': state},
    );
  }

  /// Update LED label.
  Future<void> updateLedLabel({
    required int deviceId,
    required int ledNumber,
    required String label,
  }) async {
    await _dio.patch(
      '${ApiConstants.devices}/$deviceId/night-light/leds/$ledNumber/label',
      data: {'led${ledNumber}_label': label},
    );
  }

  /// Fetch gate motion detections.
  Future<List<dynamic>> getGateDetections(int deviceId) async {
    final res = await _dio.get('${ApiConstants.gateDetections}/$deviceId/detections');
    return res.data as List<dynamic>;
  }

  /// Fetch anti-theft room detections.
  Future<List<dynamic>> getRoomDetections(int deviceId) async {
    final res = await _dio.get('${ApiConstants.roomDetections}/$deviceId/detections');
    return res.data as List<dynamic>;
  }
}
