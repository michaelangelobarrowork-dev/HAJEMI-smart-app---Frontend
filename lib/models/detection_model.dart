class DetectionModel {
  final int detectId;
  final int deviceId;
  final DateTime dateTime;
  final String detectStatus;

  DetectionModel({
    required this.detectId,
    required this.deviceId,
    required this.dateTime,
    required this.detectStatus,
  });

  factory DetectionModel.fromJson(Map<String, dynamic> json) {
    return DetectionModel(
      detectId: json['detect_id'] as int,
      deviceId: json['device_id'] as int,
      dateTime: DateTime.parse(json['date_time'] as String),
      detectStatus: json['detect_status'] as String,
    );
  }
}
