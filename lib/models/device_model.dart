class NightLightState {
  final bool autoMode;
  final bool led1State;
  final String led1Label;
  final bool led2State;
  final String led2Label;
  final bool led3State;
  final String led3Label;
  final int? ldrValue;
  final DateTime? updatedAt;

  const NightLightState({
    required this.autoMode,
    required this.led1State,
    required this.led1Label,
    required this.led2State,
    required this.led2Label,
    required this.led3State,
    required this.led3Label,
    this.ldrValue,
    this.updatedAt,
  });

  factory NightLightState.fromJson(Map<String, dynamic> json) {
    return NightLightState(
      autoMode: (json['auto_mode'] ?? json['autoMode']) ?? true, // Default to true
      led1State: (json['led1_state'] ?? json['led1State']) == true,
      led1Label: (json['led1_label'] ?? json['led1Label'])?.toString() ?? 'LED 1',
      led2State: (json['led2_state'] ?? json['led2State']) == true,
      led2Label: (json['led2_label'] ?? json['led2Label'])?.toString() ?? 'LED 2',
      led3State: (json['led3_state'] ?? json['led3State']) == true,
      led3Label: (json['led3_label'] ?? json['led3Label'])?.toString() ?? 'LED 3',
      ldrValue: json['ldr_value'] is num ? (json['ldr_value'] as num).toInt() : (json['ldrValue'] is num ? (json['ldrValue'] as num).toInt() : null),
      updatedAt: (json['updated_at'] ?? json['updatedAt']) != null
          ? DateTime.tryParse((json['updated_at'] ?? json['updatedAt']) as String)
          : null,
    );
  }
}

class DeviceModel {
  final int id;
  final String deviceName;
  final String deviceType;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final int ownerId;
  final DateTime createdAt;
  final NightLightState? nightLightState;

  const DeviceModel({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.isOnline,
    this.lastSeenAt,
    required this.ownerId,
    required this.createdAt,
    this.nightLightState,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    final stateJson = json['night_light_state'] ?? json['nightLightState'];

    return DeviceModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      deviceName: (json['device_name'] ?? json['deviceName'] ?? 'Unknown Device').toString(),
      deviceType: (json['device_type'] ?? json['deviceType'] ?? 'Generic').toString(),
      isOnline: json['is_online'] == true || json['isOnline'] == true,
      lastSeenAt: (json['last_seen_at'] ?? json['lastSeenAt']) != null
          ? DateTime.tryParse((json['last_seen_at'] ?? json['lastSeenAt']) as String)
          : null,
      ownerId: int.tryParse((json['owner_id'] ?? json['ownerId'])?.toString() ?? '0') ?? 0,
      createdAt: (json['created_at'] ?? json['createdAt']) != null
          ? (DateTime.tryParse((json['created_at'] ?? json['createdAt']) as String) ?? DateTime.now())
          : DateTime.now(),
      nightLightState: stateJson != null
          ? NightLightState.fromJson(stateJson as Map<String, dynamic>)
          : null,
    );
  }
}
