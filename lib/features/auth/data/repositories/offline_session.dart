/// Whether the user chose to work without an account.
///
/// An interface rather than a concrete class for the same reason
/// `AuthRepository` is one: the provider needs to be able to ask, and a test
/// needs to be able to answer without a preferences plugin behind it.
///
/// A flag rather than a session, deliberately. Offline mode holds no
/// credentials and talks to no server, so there is nothing to refresh and
/// nothing to expire -- all it has to survive is an app restart, which is a
/// single boolean.
abstract interface class OfflineSession {
  /// Whether offline mode was the last thing the user asked for.
  ///
  /// True after a cold start means the pharmacy tablet came back up with no
  /// signal and should go straight to the price list rather than greeting a
  /// pharmacist at a counter with a login form.
  Future<bool> read();

  /// Records the choice, or clears it with a null.
  Future<void> write(bool active);
}

/// The flag in the app's own storage.
///
/// The two callbacks rather than a `SharedPreferences` handle, for the reason
/// `StoredPendingWriteQueue` takes them: the caller owns the plugin, and a test
/// can hand over a pair of closures instead of standing up a platform channel.
class StoredOfflineSession implements OfflineSession {
  StoredOfflineSession({
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

  static const String _active = 'active';

  @override
  Future<bool> read() async {
    try {
      return await _readStorage() == _active;
    } catch (_) {
      // Unreadable storage is not a reason to lock anybody out. A pharmacist who
      // tapped "Continue offline" and then found themselves back on the login
      // screen would conclude the app had lost their catalogue, when all that
      // happened is one failed read.
      return false;
    }
  }

  @override
  Future<void> write(bool active) async {
    try {
      await _writeStorage(active ? _active : null);
    } catch (_) {
      // The in-memory status has already been applied by the caller, so a write
      // that fails costs the *next* cold start its offline mode and nothing
      // about the session being used right now.
    }
  }
}

/// An offline session that never persists, for a caller with nowhere to put one.
///
/// The default for `AuthProvider`, so a test that does not care about the flag
/// does not have to say so at every call site.
class InMemoryOfflineSession implements OfflineSession {
  InMemoryOfflineSession([this.active = false]);

  bool active;

  @override
  Future<bool> read() async => active;

  @override
  Future<void> write(bool active) async => this.active = active;
}
