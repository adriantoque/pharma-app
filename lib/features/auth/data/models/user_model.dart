import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/user_role.dart';

class UserModel {
  final String id;
  final String? name;
  final String? email;

  /// What this account is allowed to do. Defaults to [UserRole.staff] when
  /// nothing more specific is known -- safer than admin, more useful than
  /// guest, and the role a new signup would receive anyway.
  final UserRole role;

  const UserModel({
    required this.id,
    this.name,
    this.email,
    this.role = UserRole.staff,
  });

  factory UserModel.fromFirebase(User user) {
    return UserModel(
      id: user.uid,
      name: user.displayName,
      email: user.email,
      // A Firebase account carries no role of its own. Any role assignment
      // lives in Firestore, which this factory does not read -- callers that
      // need the real role fetch it separately.
      role: UserRole.staff,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.storageKey,
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }
}