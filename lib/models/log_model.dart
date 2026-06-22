class LogModel {
  final int id;
  final String actionType;
  final String message;
  final int? deviceId;
  final DateTime? createdAt;
  final String? details;

  const LogModel({
    required this.id,
    required this.actionType,
    required this.message,
    this.deviceId,
    this.createdAt,
    this.details,
  });

  factory LogModel.fromJson(Map<String, dynamic> json) {
    final actionType = (json['action_type'] ?? json['type'] ?? json['event'] ?? 'activity')
        .toString();

    final message = (json['message'] ??
            json['details'] ??
            json['description'] ??
            json['action'] ??
            'Activity log')
        .toString();

    return LogModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      actionType: actionType,
      message: message,
      deviceId: json['device_id'] == null
          ? null
          : int.tryParse(json['device_id'].toString()),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : (json['timestamp'] != null
              ? DateTime.tryParse(json['timestamp'].toString())
              : null),
      details: json['details']?.toString(),
    );
  }
}
