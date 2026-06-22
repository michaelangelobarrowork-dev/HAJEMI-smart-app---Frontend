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
      autoMode:  json['auto_mode']  as bool,
      led1State: json['led1_state'] as bool,
      led1Label: json['led1_label'] as String,
      led2State: json['led2_state'] as bool,
      led2Label: json['led2_label'] as String,
      led3State: json['led3_state'] as bool,
      led3Label: json['led3_label'] as String,
      ldrValue:  json['ldr_value']  as int?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

class DeviceModel {
  final String id;
  final String deviceName;
  final String deviceType;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final String ownerId;
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
    return DeviceModel(
      id:         json['id']          as String,
      deviceName: json['device_name'] as String,
      deviceType: json['device_type'] as String,
      isOnline:   json['is_online']   as bool,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'] as String)
          : null,
      ownerId:   json['owner_id']   as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      nightLightState: json['night_light_state'] != null
          ? NightLightState.fromJson(
              json['night_light_state'] as Map<String, dynamic>)
          : null,
    );
  }
}
