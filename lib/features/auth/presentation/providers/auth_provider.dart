import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/demo_auth_repository.dart';
import '../../data/repositories/offline_pin.dart';
import '../../data/repositories/offline_session.dart';
import '../../domain/user_role.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, offline }

class AuthProvider extends ChangeNotifier {
  AuthProvider(
    this._repository, {
    OfflineSession? offlineSession,
    RoleStore? roleStore,
    OfflinePinStore? pinStore,
  })  : _offlineSession = offlineSession ?? InMemoryOfflineSession(),
        _roleStore = roleStore ?? InMemoryRoleStore(),
        _pinStore = pinStore ?? InMemoryOfflinePinStore() {
    _authSubscription = _repository.authStateChanges.listen(_onAuthStateChanged);
    _ready = _verifySession();
  }

  static const String offlineUserId = 'offline';

  static const UserModel offlineUser = UserModel(
    id: offlineUserId,
    name: 'Guest',
    email: null,
    role: UserRole.guest,
  );

  final AuthRepository _repository;
  final OfflineSession _offlineSession;
  final RoleStore _roleStore;
  final OfflinePinStore _pinStore;
  StreamSubscription<UserModel?>? _authSubscription;
  late final Future<void> _ready;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  UserRole? _role;
  bool _isLoading = false;
  bool _requestInFlight = false;
  String? _error;

  /// Whether the offline session has been let past the PIN pad.
  ///
  /// True except on a cold start that restored an offline session with a PIN
  /// on file: the tablet boots to the pad instead of the price list, and only a
  /// correct PIN moves this back to true.
  bool _offlineUnlocked = true;

  /// Wrong PIN entries since the last success or cooldown, and the moment the
  /// keypad comes back. Deliberately in memory: a persisted counter that
  /// survives a restart would keep an honest user out for good.
  int _failedPinAttempts = 0;
  DateTime? _pinCooldownUntil;

  /// Set in [dispose]. Notifying a disposed ChangeNotifier throws, and an
  /// async auth callback can still land after the tree has torn the provider
  /// down -- most easily reproduced by hot reload.
  bool _disposed = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  UserRole? get role => _role;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// What the signed-in account may do. Null while no role has been resolved
  /// yet, which is not the same as [UserRole.guest]: a role that has not been
  /// read is not a role that forbids everything.
  /// How many consecutive wrong PINs are allowed before a cooldown.
  static const int maxPinAttempts = 5;

  /// How long the keypad stays disabled after [maxPinAttempts] wrong PINs.
  static const Duration pinCooldown = Duration(seconds: 30);

  /// Whether an offline session still needs its PIN entered.
  bool get offlineLocked => _status == AuthStatus.offline && !_offlineUnlocked;

  /// Whether the offline session has been unlocked (always true for online).
  bool get offlineUnlocked => _offlineUnlocked;

  /// Wrong entries in the current run, for the "N tries left" line.
  int get failedPinAttempts => _failedPinAttempts;

  /// Time left before the keypad accepts entries again.
  Duration get pinCooldownRemaining {
    final until = _pinCooldownUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) {
      _pinCooldownUntil = null;
      return Duration.zero;
    }
    return remaining;
  }

  /// Whether a PIN has been set on this install.
  Future<bool> get hasOfflinePin => _pinStore.hasPin();

  bool get isAdmin => _role == UserRole.admin;
  bool get isStaff => _role == UserRole.staff;
  bool get isGuest => _role == UserRole.guest;

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Completes once the persisted session has been resolved, after which
  /// [status] is guaranteed to be either [AuthStatus.authenticated] or
  /// [AuthStatus.unauthenticated]. Never completes with an error.
  Future<void> get ready => _ready;

  /// While true, incoming stream events are dropped in favour of the value read
  /// once session verification finishes. Always cleared, even on failure.
  bool _initializing = true;

  void _onAuthStateChanged(UserModel? user) {
    if (_initializing) return;
    _applyAuthState(user);
  }

  void _applyAuthState(UserModel? user, {bool clearError = true}) {
    final offline = user?.id == offlineUserId;

    // Firebase's stream has no offline concept, so it reports "no user" for a
    // session that was never signed in and for one the user walked away from
    // offline mode. Acting on the first would silently undo the choice they
    // just made.
    if (user == null && _status == AuthStatus.offline) return;

    _user = user;
    _role = user?.role;
    _status = offline
        ? AuthStatus.offline
        : (user == null
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated);
    if (clearError) _error = null;
    _safeNotify();
  }

  Future<void> _verifySession() async {
    try {
      await _repository.refreshUser();
    } catch (e) {
      _error = _describeError(e);
    }

    _initializing = false;

    final current = await _repository.getCurrentUser();
    if (current != null) {
      await _offlineSession.write(false);
      await _roleStore.write(current.role);
      _applyAuthState(current, clearError: _error == null);
      return;
    }

    if (await _offlineSession.read()) {
      // The role is read from preferences rather than from the offline user
      // object, so a future change to the default role does not retroactively
      // change a session that was started under the old one.
      _role = await _roleStore.read() ?? UserRole.guest;
      _user = offlineUser;
      _status = AuthStatus.offline;
      // A restored offline session with a PIN on file boots locked: the flag
      // says which mode the tablet was left in, not who is holding it.
      _offlineUnlocked = !await _pinStore.hasPin();
      _safeNotify();
      return;
    }

    _applyAuthState(null, clearError: _error == null);
  }

  Future<bool> login({required String email, required String password}) {
    return _run(
      () => _repository.login(email: email, password: password),
      onSuccess: _applyAuthState,
    );
  }

  /// Signs in, then verifies the account has administrator access.
  ///
  /// A staff credential entered on the admin door is signed back out with a
  /// message. The role check runs after the backend has answered, so a fake
  /// role cannot be claimed in the UI -- what is checked is what Firestore
  /// said, not what the form asked for.
  Future<bool> loginAsAdmin({
    required String email,
    required String password,
  }) async {
    final ok = await login(email: email, password: password);
    if (!ok) return false;

    if (_role != UserRole.admin) {
      // Sign back out so the staff session does not survive a failed admin
      // attempt. The message is set afterwards because logout() clears the
      // error field as part of its own tidy-up.
      await logout();
      _error = 'This account does not have administrator access.';
      _safeNotify();
      return false;
    }
    return true;
  }

  /// Signs in, then verifies the account is not an administrator.
  ///
  /// Symmetrical to [loginAsAdmin]: an admin credential entered on the staff
  /// door is signed back out. The two doors stay clean, so a person cannot
  /// use the wrong one by mistake and end up somewhere they were not
  /// expecting.
  Future<bool> loginAsStaff({
    required String email,
    required String password,
  }) async {
    final ok = await login(email: email, password: password);
    if (!ok) return false;

    if (_role == UserRole.admin) {
      await logout();
      _error = 'Please use the administrator sign-in for this account.';
      _safeNotify();
      return false;
    }
    return true;
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
    return _run(
      () => _repository.signInWithGoogle(),
      onSuccess: _applyAuthState,
    );
  }

  bool get isOffline => _status == AuthStatus.offline;

  Future<void> enterOfflineMode() async {
    await _offlineSession.write(true);
    await _roleStore.write(UserRole.guest);
    _status = AuthStatus.offline;
    _user = offlineUser;
    _role = UserRole.guest;
    _error = null;
    // The caller has either just set a PIN or just proved it knows it, so the
    // session it is opening is unlocked by construction.
    _offlineUnlocked = true;
    _resetPinAttempts();
    _safeNotify();
  }

  Future<void> exitOfflineMode() async {
    await _offlineSession.write(false);
    await _roleStore.write(null);
    _status = AuthStatus.unauthenticated;
    _user = null;
    _role = null;
    _error = null;
    _offlineUnlocked = true;
    _resetPinAttempts();
    _safeNotify();
  }

  /// Sets (or replaces) the PIN that guards offline mode.
  ///
  /// Called by the create flow before the offline session starts, so it also
  /// clears the failed-attempt state: the person who just chose the PIN is not
  /// someone the pad should distrust.
  Future<void> setOfflinePin(String pin) async {
    if (!isValidOfflinePin(pin)) {
      throw ArgumentError.value(pin, 'pin', 'must be four digits');
    }
    await _pinStore.save(pin);
    _offlineUnlocked = true;
    _resetPinAttempts();
    _error = null;
    _safeNotify();
  }

  /// Tries [pin] against the stored one.
  ///
  /// Returns false for a wrong PIN, during a cooldown, and when no PIN is
  /// stored — the last case because an install with no PIN has nothing to
  /// unlock and should go through the create flow instead.
  Future<bool> unlockOffline(String pin) async {
    if (pinCooldownRemaining > Duration.zero) return false;

    final ok = await _pinStore.matches(pin);
    if (ok) {
      _offlineUnlocked = true;
      _error = null;
      _resetPinAttempts();
      _safeNotify();
      return true;
    }

    _failedPinAttempts++;
    if (_failedPinAttempts >= maxPinAttempts) {
      _pinCooldownUntil = DateTime.now().add(pinCooldown);
      _failedPinAttempts = 0;
    }
    _error = 'Wrong PIN.';
    _safeNotify();
    return false;
  }

  /// Locks the offline session without ending it, for a caller that wants the
  /// pad back (an idle timeout, say) while keeping the mode and role.
  void lockOffline() {
    if (_status != AuthStatus.offline || !_offlineUnlocked) return;
    _offlineUnlocked = false;
    _safeNotify();
  }

  /// Forgets the PIN, so the next offline entry sets a new one.
  Future<void> clearOfflinePin() async {
    await _pinStore.clear();
    _safeNotify();
  }

  void _resetPinAttempts() {
    _failedPinAttempts = 0;
    _pinCooldownUntil = null;
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
      await _roleStore.write(null);
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
    // both the keyboard action and the button, and Firebase rejects the
    // second sign-in attempt as a conflict.
    if (_requestInFlight) return false;
    _requestInFlight = true;
    _isLoading = true;
    _error = null;
    _safeNotify();

    try {
      final user = await action();
      if (user != null) {
        await _roleStore.write(user.role);
        onSuccess?.call(user);
        await _offlineSession.write(false);
      }
      return user != null;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e);
      return false;
    } on AuthException catch (e) {
      _error = e.message;
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
        .replaceFirst(
          RegExp(r'^(Exception|Bad state|Unsupported error):\s*'),
          '',
        )
        .trim();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }
}