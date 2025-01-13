import 'package:borneo_app/models/base_entity.dart';

class User with BaseEntity {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  // 从 JSON 映射到 User 实例
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}
