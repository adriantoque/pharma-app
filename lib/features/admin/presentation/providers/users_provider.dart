import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/search_text.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/auth_exception.dart';
import '../../../auth/domain/user_role.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/audit_event.dart';

/// Which slice of the team the Users screen is showing.
enum UsersFilter {
  active('Active'),
  deactivated('Deactivated'),
  all('All');

  const UsersFilter(this.label);

  final String label;

  bool accepts(UserModel user) => switch (this) {
        UsersFilter.active => user.active,
        UsersFilter.deactivated => !user.active,
        UsersFilter.all => true,
      };
}

/// The state of the Users screen: who is on the team, what the search box
/// says, and the actions an admin can take on somebody.
///
/// Owns its own subscription to the users stream so the screen can rebuild
/// on any change without holding the repository itself. Built per visit
/// rather than registered above the router: an admin who signs out mid-session
/// should not leave a live subscription behind scoped to the account that
/// just left.
///
/// Every write that changes who can sign in also writes an audit entry. The
/// two are done in the same method, so a future change cannot accidentally
/// skip the log -- if the write path is reused, the log entry rides along.
class UsersProvider extends ChangeNotifier {
  UsersProvider({
    required UserRepository repository,
    required AuditRepository audit,
    required String actorUid,
    required String actorName,
  })  // A named parameter cannot be private, so `this._repository` is not
      // available and these are the only shape they can take.
      // ignore: prefer_initializing_formals
      : _repository = repository,
        // ignore: prefer_initializing_formals
        _audit = audit,
        // ignore: prefer_initializing_formals
        _actorUid = actorUid,
        // ignore: prefer_initializing_formals
        _actorName = actorName {
    _subscription = _repository.watchAll().listen(
      (users) {
        _users = users;
        _error = null;
        _hasLoaded = true;
        _safeNotify();
      },
      onError: (Object error) {
        _error = error.toString();
        _hasLoaded = true;
        _safeNotify();
      },
    );
  }

  final UserRepository _repository;
  final AuditRepository _audit;
  final String _actorUid;
  final String _actorName;

  StreamSubscription<List<UserModel>>? _subscription;

  List<UserModel> _users = const [];
  String _query = '';
  UsersFilter _filter = UsersFilter.active;
  String? _error;
  bool _isSaving = false;
  bool _hasLoaded = false;
  bool _disposed = false;

  // ── Reads ────────────────────────────────────────────────────────────────

  String get query => _query;
  UsersFilter get filter => _filter;
  String? get error => _error;
  bool get isSaving => _isSaving;

  /// True only before the first snapshot. An empty users list that has been
  /// read is not loading -- it is empty.
  bool get isLoading => !_hasLoaded;

  /// Every user on file, in the order the repository hands them over.
  List<UserModel> get users => List.unmodifiable(_users);

  /// The users the current filter and query leave visible.
  List<UserModel> get results {
    return List.unmodifiable(
      _users
          .where(_filter.accepts)
          .where(_matchesQuery),
    );
  }

  /// How many users each filter chip would show, for its label.
  Map<UsersFilter, int> get counts => {
        UsersFilter.active: _users.where((u) => u.active).length,
        UsersFilter.deactivated: _users.where((u) => !u.active).length,
        UsersFilter.all: _users.length,
      };

  /// Whether this account may be signed out of.
  ///
  /// Two reasons an admin cannot deactivate somebody: it is their own
  /// account, which would lock them out of the app they are using; or it is
  /// the last active admin, which would leave the pharmacy with nobody who
  /// can promote anybody else.
  bool canDeactivate(UserModel user) {
    if (user.id == _actorUid) return false;
    if (user.role != UserRole.admin) return true;
    return _activeAdminCount > 1;
  }

  /// Whether this account's role may be changed to [newRole].
  ///
  /// Promotions are always allowed. Demotions are refused when the target is
  /// the last active admin, or the admin themselves -- the same lockout the
  /// deactivate guard prevents, arriving through a different door.
  bool canChangeRole(UserModel user, UserRole newRole) {
    if (user.role == newRole) return false;
    if (newRole == UserRole.admin) return true;
    if (user.id == _actorUid) return false;
    if (user.role == UserRole.admin) return _activeAdminCount > 1;
    return true;
  }

  int get _activeAdminCount =>
      _users.where((u) => u.active && u.role == UserRole.admin).length;

  bool _matchesQuery(UserModel user) {
    final trimmed = _query.trim();
    if (trimmed.isEmpty) return true;
    final needle = normaliseForSearch(trimmed);
    if (normaliseForSearch(user.name ?? '').contains(needle)) return true;
    if (normaliseForSearch(user.email ?? '').contains(needle)) return true;
    if (normaliseForSearch(user.role.label).contains(needle)) return true;
    return false;
  }

  // ── Filters ──────────────────────────────────────────────────────────────

  void updateQuery(String value) {
    if (_query == value) return;
    _query = value;
    _safeNotify();
  }

  void clearQuery() => updateQuery('');

  void setFilter(UsersFilter value) {
    if (_filter == value) return;
    _filter = value;
    _safeNotify();
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  /// Creates a Firebase Auth account and its profile, then logs it.
  ///
  /// Returns true on success, false when the write failed -- a false return
  /// is always accompanied by an [error] the screen can show.
  Future<bool> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    _safeNotify();

    try {
      final created = await _repository.createUser(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      await _audit.record(
        action: AuditAction.userCreated,
        actorUid: _actorUid,
        actorName: _actorName,
        summary: 'Created user ${created.name} '
            '(${created.role.label.toLowerCase()})',
        targetId: created.id,
        after: created.toFirestore(),
      );
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Could not create the account. $e';
      return false;
    } finally {
      _isSaving = false;
      _safeNotify();
    }
  }

  /// Updates the fields an admin may change about somebody else.
  ///
  /// Builds the audit summary from what actually differs, so a save that
  /// changes nothing does not write a log entry that says something did.
  Future<bool> updateUser(
    UserModel user, {
    String? name,
    UserRole? role,
  }) async {
    if (_isSaving) return false;
    final nameChanged = name != null && name != user.name;
    final roleChanged = role != null && role != user.role;
    if (!nameChanged && !roleChanged) return true;

    _isSaving = true;
    _error = null;
    _safeNotify();

    try {
      await _repository.updateUser(
        uid: user.id,
        name: nameChanged ? name : null,
        role: roleChanged ? role : null,
      );

      if (roleChanged) {
        await _audit.record(
          action: AuditAction.userUpdated,
          actorUid: _actorUid,
          actorName: _actorName,
          summary: 'Changed role for ${user.name}: '
              '${user.role.label} → ${role.label}',
          targetId: user.id,
          before: {'role': user.role.storageKey},
          after: {'role': role.storageKey},
        );
      }
      if (nameChanged) {
        await _audit.record(
          action: AuditAction.userUpdated,
          actorUid: _actorUid,
          actorName: _actorName,
          summary: 'Renamed ${user.name} to $name',
          targetId: user.id,
          before: {'displayName': user.name},
          after: {'displayName': name},
        );
      }
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Could not save the changes. $e';
      return false;
    } finally {
      _isSaving = false;
      _safeNotify();
    }
  }

  /// Turns sign-in on or off for an account.
  Future<bool> setActive(UserModel user, bool active) async {
    if (_isSaving) return false;
    if (user.active == active) return true;

    _isSaving = true;
    _error = null;
    _safeNotify();

    try {
      await _repository.setActive(user.id, active);
      await _audit.record(
        action: active
            ? AuditAction.userReactivated
            : AuditAction.userDeactivated,
        actorUid: _actorUid,
        actorName: _actorName,
        summary: '${active ? 'Reactivated' : 'Deactivated'} ${user.name}',
        targetId: user.id,
        before: {'active': user.active},
        after: {'active': active},
      );
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Could not ${active ? 'reactivate' : 'deactivate'} the '
          'account. $e';
      return false;
    } finally {
      _isSaving = false;
      _safeNotify();
    }
  }

  /// Asks Firebase to email a reset link, and logs it.
  ///
  /// The log entry is written even when the user does not click the link.
  /// "A reset was sent" and "the password was changed" are different facts,
  /// and only the first happened here.
  Future<bool> sendPasswordReset(UserModel user) async {
    if (_isSaving) return false;
    final email = user.email;
    if (email == null || email.isEmpty) {
      _error = 'This account has no email on file.';
      _safeNotify();
      return false;
    }

    _isSaving = true;
    _error = null;
    _safeNotify();

    try {
      await _repository.sendPasswordReset(email);
      await _audit.record(
        action: AuditAction.userPasswordReset,
        actorUid: _actorUid,
        actorName: _actorName,
        summary: 'Sent a password reset to $email',
        targetId: user.id,
      );
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Could not send the reset email. $e';
      return false;
    } finally {
      _isSaving = false;
      _safeNotify();
    }
  }

  /// Clears a reported error, once the screen has shown it.
  void clearError() {
    if (_error == null) return;
    _error = null;
    _safeNotify();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}