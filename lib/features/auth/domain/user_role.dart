/// What a signed-in account is allowed to do.
///
/// Separate from `AuthStatus`, which answers "is anybody signed in?". A role
/// answers "what can they do?", and the two are genuinely different questions:
/// a guest is signed in as far as the router is concerned, and a staff member
/// who has stepped away from the counter is still staff.
enum UserRole {
  /// The pharmacy owner or manager: everything, including reports.
  admin,

  /// Counter staff: sales, orders, stock counting, no reports.
  staff,

  /// A visitor or a device working without an account: browse only.
  guest;

  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.staff => 'Staff',
        UserRole.guest => 'Guest',
      };

  /// Stored in preferences under this name. Kept stable: a rename here would
  /// invalidate every stored session.
  String get storageKey => name;

  static UserRole? fromStorage(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final role in UserRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }
}

/// What each role can do.
///
/// A single place so a screen asks `role.canSell` rather than comparing to
/// `UserRole.guest` itself. When the rules change, they change here.
extension UserRoleCapabilities on UserRole {
  bool get canSell => this != UserRole.guest;
  bool get canApproveOrders => this != UserRole.guest;
  bool get canCountStock => this != UserRole.guest;
  bool get canEditCatalogue => this != UserRole.guest;
  bool get canViewReports => this == UserRole.admin;
  bool get canManageUsers => this == UserRole.admin;
}

/// Where the signed-in role is remembered between launches.
///
/// The same closures-rather-than-`SharedPreferences` shape `OfflineSession`
/// uses: the caller owns the plugin, and a test can hand over a pair of
/// in-memory closures without standing up a platform channel.
abstract interface class RoleStore {
  Future<UserRole?> read();
  Future<void> write(UserRole? role);
}

class StoredRoleStore implements RoleStore {
  StoredRoleStore({
    required Future<String?> Function() readStorage,
    required Future<void> Function(String? value) writeStorage,
  })  // A named parameter cannot be private, so this is the only shape it can
      // take.
      // ignore: prefer_initializing_formals
      : _readStorage = readStorage,
        // ignore: prefer_initializing_formals
        _writeStorage = writeStorage;

  final Future<String?> Function() _readStorage;
  final Future<void> Function(String? value) _writeStorage;

  @override
  Future<UserRole?> read() async {
    try {
      return UserRole.fromStorage(await _readStorage());
    } catch (_) {
      // Unreadable storage is not a reason to lock anybody out. Falling back
      // to no role means the next sign-in sets one.
      return null;
    }
  }

  @override
  Future<void> write(UserRole? role) async {
    try {
      await _writeStorage(role?.storageKey);
    } catch (_) {
      // A write that fails costs the *next* cold start its remembered role
      // and nothing about the session being used right now.
    }
  }
}

/// A role store that keeps its value in memory only. The default in tests.
class InMemoryRoleStore implements RoleStore {
  InMemoryRoleStore([this.role]);

  UserRole? role;

  @override
  Future<UserRole?> read() async => role;

  @override
  Future<void> write(UserRole? role) async => this.role = role;
}