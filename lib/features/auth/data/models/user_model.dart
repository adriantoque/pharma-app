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

  /// Whether the account may sign in at all.
  ///
  /// Firebase Auth has no concept of a disabled account the client can set,
  /// so the flag lives in Firestore and the repository checks it after a
  /// successful sign-in and signs the session back out when it is false.
  /// Defaulting to true keeps a user doc that predates this field usable.
  final bool active;

  const UserModel({
    required this.id,
    this.name,
    this.email,
    this.role = UserRole.staff,
    this.active = true,
  });

  /// From a Firebase Auth user alone, with no Firestore document to consult.
  ///
  /// The role is always [UserRole.staff] here: an Auth account carries no
  /// role of its own, and any real assignment lives in `users/{uid}`. Callers
  /// that need the real role should read the document -- the repository does
  /// that on every sign-in through [_fromFirestore].
  factory UserModel.fromFirebase(User user) {
    return UserModel(
      id: user.uid,
      name: user.displayName,
      email: user.email,
    );
  }

  /// The full record: Firebase Auth's own values filled in by the Firestore
  /// document where it has one.
  ///
  /// [data] is nullable because the document may not exist yet -- a user
  /// created before this feature, or a sign-in that lands a moment before
  /// the profile write does. Missing fields fall back to the Auth values so
  /// the app has something to render rather than nothing.
  factory UserModel.fromFirestore({
    required String uid,
    required Map<String, dynamic>? data,
    String? fallbackName,
    String? fallbackEmail,
  }) {
    if (data == null) {
      return UserModel(
        id: uid,
        name: fallbackName,
        email: fallbackEmail,
      );
    }
    return UserModel(
      id: uid,
      name: (data['displayName'] as String?) ?? fallbackName,
      email: (data['email'] as String?) ?? fallbackEmail,
      role: UserRole.fromStorage(data['role'] as String?) ?? UserRole.staff,
      active: (data['active'] as bool?) ?? true,
    );
  }

  /// The Firestore representation of the fields this model owns.
  ///
  /// Timestamps are the caller's business -- `createdAt` is stamped once, at
  /// creation, and `updatedAt` on every write, neither of which this model
  /// knows about.
  Map<String, dynamic> toFirestore() => {
        'displayName': name,
        'email': email,
        'role': role.storageKey,
        'active': active,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.storageKey,
        'active': active,
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    bool? active,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      active: active ?? this.active,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          other.id == id &&
          other.name == name &&
          other.email == email &&
          other.role == role &&
          other.active == active;

  @override
  int get hashCode => Object.hash(id, name, email, role, active);
}