import '../models/user_model.dart';

abstract class AuthRepository {
  Stream<UserModel?> get authStateChanges;

  Future<UserModel> login({
    required String email,
    required String password,
  });

  Future<UserModel> signup({
    required String name,
    required String email,
    required String password,
  });

  Future<UserModel?> signInWithGoogle();

  Future<void> logout();

  Future<UserModel?> getCurrentUser();

  Future<UserModel?> refreshUser();
}