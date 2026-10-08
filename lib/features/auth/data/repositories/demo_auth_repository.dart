import 'dart:async';

import '../../domain/user_role.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

/// An [AuthRepository] whose accounts are compiled into the app.
///
/// For demonstration and early testing: three fixed users, checked in Dart,
/// with no network, no Firebase and no Firestore. The role each one produces
/// comes from the same [UserRole] the real path would use, so a screen
/// checking `role.canSell` cannot tell the difference between this and a
/// production backend.
///
/// Two accounts, in fact -- "admin" and "staff" -- plus the guest path, which
/// does not go through this class at all and instead uses the existing
/// offline-mode flag. The guest button on the landing screen flips that flag,
/// which is why this repository has no guest account in it.
///
/// The passwords are visible in the compiled binary. That is fine for a demo
/// and unacceptable in production: swapping this for [FirebaseAuthRepository]
/// in `main.dart` is the entire migration, and nothing else needs to change.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository();

  /// One entry per account: password and the role it signs in as.
  static const Map<String, ({String password, UserRole role})> _accounts = {
    'admin': (password: 'admin123', role: UserRole.admin),
    'staff': (password: 'staff123', role: UserRole.staff),
  };

  /// The account currently signed in, held in memory only. A cold start has
  /// no session; the provider restores the *role* from preferences and asks
  /// this class for nothing, because there is nothing to ask.
  UserModel? _current;

  final StreamController<UserModel?> _changes =
      StreamController<UserModel?>.broadcast();

  @override
  Stream<UserModel?> get authStateChanges => _changes.stream;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    // Small delay so the UI's loading state is visible for one frame rather
    // than appearing not to have run. A real sign-in has latency; a button
    // that resolves instantly reads as broken.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final username = email.trim().toLowerCase();
    final account = _accounts[username];

    if (account == null || account.password != password) {
      throw const AuthException(
        'Incorrect username or password.',
      );
    }

    final user = UserModel(
      id: username,
      name: username == 'admin' ? 'Administrator' : 'Staff',
      email: '$username@pharmaguide.local',
      role: account.role,
    );
    _current = user;
    _changes.add(user);
    return user;
  }

  @override
  Future<UserModel> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    // Signups are disabled in demo mode: there is no persistent store to put
    // a new account in, and inventing one only until the next launch would be
    // worse than saying no.
    throw const AuthException(
      'Signup is disabled in demo mode. Sign in with a demo account.',
    );
  }

  @override
  Future<UserModel?> signInWithGoogle() async {
    // Not supported in demo mode. Returning null is the interface's "the user
    // backed out", which the caller already handles.
    return null;
  }

  @override
  Future<void> logout() async {
    _current = null;
    _changes.add(null);
  }

  @override
  Future<UserModel?> getCurrentUser() async => _current;

  @override
  Future<UserModel?> refreshUser() async => _current;
}

/// A sign-in that was refused for a reason the screen can show.
///
/// Distinct from a transport error so the provider can tell "wrong password"
/// (the user retypes it) from "the network is down" (the user tries again
/// later), which is the same distinction `AuthProvider` already makes for
/// `FirebaseAuthException`.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}