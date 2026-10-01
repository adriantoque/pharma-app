import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/offline_session.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, offline }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository, {OfflineSession? offlineSession})
      : _offlineSession = offlineSession ?? InMemoryOfflineSession() {
    _authSubscription = _repository.authStateChanges.listen(_onAuthStateChanged);
    _ready = _verifySession();
  }

  static const String offlineUserId = 'offline';

  static const UserModel offlineUser = UserModel(
    id: offlineUserId,
    name: 'Offline mode',
    email: null,
  );

  final AuthRepository _repository;
  final OfflineSession _offlineSession;
  StreamSubscription<UserModel?>? _authSubscription;
  late final Future<void> _ready;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  bool _isLoading = false;
  bool _requestInFlight = false;
  String? _error;

  /// Set in [dispose]. Notifying a disposed ChangeNotifier throws, and an async
  /// auth callback can still land after the widget tree has torn the provider
  /// down — most easily reproduced by hot reload, which disposes and rebuilds
  /// the provider while a Firebase call is still in flight.
  bool _disposed = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Completes once the persisted session has been resolved, after which
  /// [status] is guaranteed to be either [AuthStatus.authenticated] or
  /// [AuthStatus.unauthenticated]. Never completes with an error.
  Future<void> get ready => _ready;

  /// While true, incoming stream events are dropped in favour of the value read
  /// once session verification finishes. Always cleared, even on failure, so a
  /// transient error can never permanently freeze the auth state machine.
  bool _initializing = true;

  void _onAuthStateChanged(UserModel? user) {
    if (_initializing) return;
    _applyAuthState(user);
  }

  void _applyAuthState(UserModel? user, {bool clearError = true}) {
    // The guest user is a real [UserModel], so without this it would read as
    // authenticated -- which is the whole trap here. Keyed on the reserved id
    // rather than on a flag, so no caller can reach offline mode by accident.
    final offline = user?.id == offlineUserId;

    // Firebase's stream has no offline concept, so it reports "no user" for a
    // session that was never signed in and for one the user walked away from
    // offline mode. Acting on the first would silently undo the choice they just
    // made and drop them back on the login screen a frame after entering.
    //
    // A real user still wins: signing in while offline is a deliberate
    // replacement, not a stray event.

    // Firebase's stream has no offline concept, so it reports "no user" for a
    // session that was never signed in and for one the user walked away from
    // offline mode. Acting on the first would silently undo the choice they just
    // made and drop them back on the login screen a frame after entering.
    //
    // A real user still wins: signing in while offline is a deliberate
    // replacement, not a stray event.
    if (user == null && _status == AuthStatus.offline) return;

    _user = user;
    _status = offline
        ? AuthStatus.offline
        : (user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated);
    // A state change means whatever the previous request reported is no longer
    // the current error, so a failed sign-in message must not survive a sign-out
    // and greet the user on the login screen.
    if (clearError) _error = null;
    _safeNotify();
  }

  Future<void> _verifySession() async {
    try {
      await _repository.refreshUser();
    } catch (e) {
      // Never let this escape: an unhandled error here used to leave
      // _initializing stuck at true, which silently discarded every later
      // auth event and pinned the app to the login screen.
      _error = _describeError(e);
    }

    _initializing = false;

    final current = await _repository.getCurrentUser();
    if (current != null) {
      await _offlineSession.write(false);
      _applyAuthState(current, clearError: _error == null);
      return;
    }

    if (await _offlineSession.read()) {
      _applyAuthState(offlineUser, clearError: _error == null);
      return;
    }

    // Seed from the live Firebase session *after* stream events are being
    // accepted, so a sign-in that raced the refresh is not lost. getCurrentUser
    // reads authoritative state, so a concurrent sign-out is picked up too.
    // clearError is false only when the refresh above actually failed, so that
    // diagnostic survives instead of being wiped by the state change.
    _applyAuthState(null, clearError: _error == null);
  }

  Future<bool> login({required String email, required String password}) {
    return _run(
      () => _repository.login(email: email, password: password),
      onSuccess: _applyAuthState,
    );
  }

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
  }) {
    return _run(
      () => _repository.signup(name: name, email: email, password: password),
      onSuccess: _applyAuthState,
    );
  }

  Future<bool> signInWithGoogle() {
    return _run(() => _repository.signInWithGoogle(), onSuccess: _applyAuthState);
  }

  bool get isOffline => _status == AuthStatus.offline;

  Future<void> enterOfflineMode() async {
    await _offlineSession.write(true);
    _status = AuthStatus.offline;
    _user = offlineUser;
    _error = null;
    _safeNotify();
  }

  Future<void> exitOfflineMode() async {
    await _offlineSession.write(false);
    _status = AuthStatus.unauthenticated;
    _user = null;
    _error = null;
    _safeNotify();
  }

  Future<bool> logout() async {
    if (_requestInFlight) return false;
    _requestInFlight = true;
    _isLoading = true;
    _error = null;
    _safeNotify();

    try {
      await _repository.logout();
      await _offlineSession.write(false);
      return true;
    } catch (e) {
      _error = _describeError(e);
      return false;
    } finally {
      _isLoading = false;
      _requestInFlight = false;
      _safeNotify();
    }
  }

  Future<bool> _run(
    Future<UserModel?> Function() action, {
    void Function(UserModel? user)? onSuccess,
  }) async {
    // Guard against double submission: the auth sheet triggers _submit from
    // both the keyboard action and the button, and Firebase rejects the second
    // sign-in attempt as a conflict.
    if (_requestInFlight) return false;
    _requestInFlight = true;
    _isLoading = true;
    _error = null;
    _safeNotify();

    try {
      final user = await action();
      if (user != null) {
        onSuccess?.call(user);
        // Every sign-in path goes through here, so this is the one place that has
        // to forget offline mode. Left set, the next cold start would find the
        // flag and drop a properly signed-in pharmacist into a guest session.
        await _offlineSession.write(false);
      }
      return user != null;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e);
      return false;
    } on PlatformException catch (e) {
      _error = _mapPlatformError(e);
      return false;
    } catch (e) {
      _error = _describeError(e);
      return false;
    } finally {
      _isLoading = false;
      _requestInFlight = false;
      _safeNotify();
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-credential':
        return 'That email and password combination is not valid.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'operation-not-allowed':
        return 'Signups are blocked. Enable the Email/Password provider in Firebase.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'requires-recent-login':
        return 'Please sign in again before making this change.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }

  String _mapPlatformError(PlatformException e) {
    switch (e.code) {
      case 'sign_in_canceled':
        return 'Google sign-in was cancelled.';
      case 'network_error':
        return 'Network error. Check your connection and try again.';
      case 'sign_in_failed':
        return 'Google sign-in failed. Make sure this device has Google Play services '
            'and a Google account, and that the app is registered.';
      default:
        return e.message ?? 'Sign-in failed. Please try again.';
    }
  }

  String _describeError(Object error) {
    final text = error.toString();
    return text
        .replaceFirst(RegExp(r'^(Exception|Bad state|Unsupported error):\s*'), '')
        .trim();
  }

  @override
  void dispose() {
    // Flipped before the subscription is cancelled: cancelling is async, so an
    // in-flight callback can still arrive after this returns.
    _disposed = true;
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }
}
