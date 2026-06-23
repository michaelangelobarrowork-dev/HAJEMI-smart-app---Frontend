class LogModel {
  final String id;
  final String deviceId;
  final String? deviceName;
  final String? performedBy;
  final String? performerUsername;
  final String actionType;
  final int? ledNumber;
  final String? ledLabel;
  final String triggeredBy;
  final DateTime createdAt;

  const LogModel({
    required this.id,
    required this.deviceId,
    this.deviceName,
    this.performedBy,
    this.performerUsername,
    required this.actionType,
    this.ledNumber,
    this.ledLabel,
    required this.triggeredBy,
    required this.createdAt,
  });

  factory LogModel.fromJson(Map<String, dynamic> json) {
    return LogModel(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      deviceName: json['device_name']?.toString(),
      performedBy: json['performed_by']?.toString(),
      performerUsername: json['performer_username']?.toString(),
      actionType: json['action_type']?.toString() ?? 'activity',
      ledNumber: json['led_number'] is int ? json['led_number'] as int : null,
      ledLabel: json['led_label']?.toString(),
      triggeredBy: json['triggered_by']?.toString() ?? 'Unknown',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  String get message {
    if (actionType == 'toggle_led') {
      return 'Toggled LED ${ledLabel ?? ledNumber ?? ''}';
    }
    if (actionType == 'toggle_auto_mode') {
      return 'Auto Mode toggled';
    }
    return actionType.replaceAll('_', ' ').toUpperCase();
  }

  String get performerDisplay {
    return performerUsername ?? performedBy ?? triggeredBy;
  }
}
