import 'dart:async';

import 'package:pharmaguide/features/auth/data/models/user_model.dart';
import 'package:pharmaguide/features/auth/data/repositories/auth_repository.dart';

/// Controllable fake used by the auth and routing tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.currentUser});

  UserModel? currentUser;
  final StreamController<UserModel?> _controller =
      StreamController<UserModel?>.broadcast();

  /// Number of times a sign-in attempt actually reached the "server".
  int loginAttempts = 0;
  int signupAttempts = 0;
  int logoutCalls = 0;

  /// When set, the next refreshUser call throws this instead of resolving.
  Object? refreshUserError;

  /// When set, the next sign-in attempt throws this instead of succeeding.
  Object? loginError;

  /// When true, refreshUser hangs until [completeRefresh] is called.
  bool blockRefresh = false;
  Completer<void>? _refreshGate;

  @override
  Stream<UserModel?> get authStateChanges => _controller.stream;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    loginAttempts++;
    if (loginError != null) throw loginError!;
    final user = UserModel(id: '1', name: email, email: email);
    currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<UserModel> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    signupAttempts++;
    final user = UserModel(id: '1', name: name, email: email);
    currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<UserModel?> signInWithGoogle() async {
    final user = UserModel(id: 'google-1', name: 'Google User', email: 'g@x.com');
    currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    currentUser = null;
    _controller.add(null);
  }

  @override
  Future<UserModel?> getCurrentUser() async => currentUser;

  @override
  Future<UserModel?> refreshUser() async {
    if (refreshUserError != null) throw refreshUserError!;
    if (blockRefresh) {
      _refreshGate = Completer<void>();
      await _refreshGate!.future;
    }
    return currentUser;
  }

  /// Emits a fresh auth state as Firebase would after a sign-in/sign-out.
  void emit(UserModel? user) {
    currentUser = user;
    _controller.add(user);
  }

  void completeRefresh() {
    _refreshGate?.complete();
    _refreshGate = null;
  }

  /// Closes the stream without awaiting the drain: a broadcast controller's
  /// `done` future only completes once every subscription is cancelled, and
  /// `AuthProvider.dispose()` cancels asynchronously, so awaiting here would
  /// hang the test teardown forever.
  void dispose() {
    if (!_controller.isClosed) unawaited(_controller.close());
  }
}
