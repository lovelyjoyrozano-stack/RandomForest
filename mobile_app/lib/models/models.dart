import '../core/format.dart';

class User {
  final int id;
  final String fullName;
  final String username;
  final String role;

  const User({
    required this.id,
    required this.fullName,
    required this.username,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: asInt(j['user_id']) ?? 0,
        fullName: j['full_name']?.toString() ?? '',
        username: j['username']?.toString() ?? '',
        role: j['role']?.toString() ?? 'Farmer',
      );

  Map<String, dynamic> toJson() => {
        'user_id': id,
        'full_name': fullName,
        'username': username,
        'role': role,
      };
}

class Farm {
  final int id;
  final String code;
  final String name;
  final String location;
  final String status;
  final double? areaHectares;
  final String? city;

  const Farm({
    required this.id,
    required this.code,
    required this.name,
    required this.location,
    required this.status,
    this.areaHectares,
    this.city,
  });

  factory Farm.fromJson(Map<String, dynamic> j) => Farm(
        id: asInt(j['farm_id']) ?? 0,
        code: j['farm_code']?.toString() ?? '',
        name: j['farm_name']?.toString() ?? '',
        location: j['location']?.toString() ?? '',
        status: j['status']?.toString() ?? 'Active',
        areaHectares: asDouble(j['area_hectares']),
        city: j['city']?.toString(),
      );
}
