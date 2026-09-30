import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String id;
  final String? name;
  final String? email;

  const UserModel({required this.id, this.name, this.email});

  factory UserModel.fromFirebase(User user) {
    return UserModel(
      id: user.uid,
      name: user.displayName,
      email: user.email,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
      };
}