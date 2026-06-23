import 'device_model.dart';

class HouseholdMember {
  final int id;
  final String username;
  final String email;
  final bool isCreator;

  const HouseholdMember({
    required this.id,
    required this.username,
    required this.email,
    required this.isCreator,
  });

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    return HouseholdMember(
      id: json['id'] as int,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isCreator: json['is_creator'] == true,
    );
  }
}

class HouseholdModel {
  final int id;
  final String name;
  final int creatorId;
  final String joinCode;
  final DateTime createdAt;
  final List<HouseholdMember> members;

  const HouseholdModel({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.joinCode,
    required this.createdAt,
    required this.members,
  });

  factory HouseholdModel.fromJson(Map<String, dynamic> json) {
    return HouseholdModel(
      id: json['id'] as int,
      name: json['name']?.toString() ?? 'My Home',
      creatorId: json['creator_id'] as int,
      joinCode: json['join_code']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String) ?? DateTime.now())
          : DateTime.now(),
      members: (json['members'] as List?)
              ?.map((e) => HouseholdMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
