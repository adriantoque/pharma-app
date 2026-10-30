import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// The 4-digit PIN that guards the app's offline mode.
///
/// Same shape as [OfflineSession] and [RoleStore]: an interface plus a
/// stored implementation built from storage closures, so the provider can ask
/// without owning a `SharedPreferences` handle and a test can answer without a
/// platform channel.
///
/// What this is, and is not: a convenience lock for a counter tablet, not
/// credential security. Four digits is ten thousand combinations, and anyone
/// who can read the app's storage can grind through them offline. Storing a
/// salted hash rather than the PIN keeps the value out of a plain-text dump and
/// out of the logs; the attempt limit in `AuthProvider` is what makes guessing
/// through the UI expensive.
abstract interface class OfflinePinStore {
  /// Whether a PIN has ever been set on this install.
  Future<bool> hasPin();

  /// Replaces the stored PIN with [pin].
  ///
  /// The plain PIN never reaches storage: an implementation is expected to
  /// hash it first.
  Future<void> save(String pin);

  /// Whether [pin] is the stored one. False when nothing is stored.
  Future<bool> matches(String pin);

  /// Forgets the PIN, leaving the install back at first-run.
  Future<void> clear();
}

/// Whether [pin] is a usable PIN for this feature.
///
/// Four digits, nothing else. Kept next to the store so the screen, the
/// provider and the stored format cannot disagree about what "valid" means.
bool isValidOfflinePin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

/// The PIN in the app's own storage, as `v1$salt$hash`.
///
/// The version prefix is deliberate: if the scheme ever changes, old values
/// are recognised as unreadable rather than silently failing every check.
class StoredOfflinePinStore implements OfflinePinStore {
  StoredOfflinePinStore({
    required Future<String?> Function() readStorage,
    required Future<void> Function(String? value) writeStorage,
    Random? random,
  })  // A named parameter cannot be private, so this is the only shape it can
      // take.
      // ignore: prefer_initializing_formals
      : _readStorage = readStorage,
        // ignore: prefer_initializing_formals
        _writeStorage = writeStorage,
        _random = random ?? Random.secure();

  final Future<String?> Function() _readStorage;
  final Future<void> Function(String? value) _writeStorage;
  final Random _random;

  static const String _prefix = 'v1';
  static const int _saltBytes = 16;

  @override
  Future<bool> hasPin() async => await _read() != null;

  @override
  Future<void> save(String pin) async {
    if (!isValidOfflinePin(pin)) {
      throw ArgumentError.value(pin, 'pin', 'must be four digits');
    }
    final salt = _newSalt();
    // Braces around the call: a bare `$_hash(salt, pin)` would interpolate the
    // method tear-off and leave the arguments as literal text.
    final value = '$_prefix\$$salt\$${_hash(salt, pin)}';
    try {
      await _writeStorage(value);
    } catch (_) {
      // A write that fails leaves the previous PIN in place. The caller has
      // already verified the person, so this costs the *next* cold start its
      // lock rather than the session being used right now.
    }
  }

  @override
  Future<bool> matches(String pin) async {
    final stored = await _read();
    if (stored == null) return false;
    if (!isValidOfflinePin(pin)) return false;
    final parts = stored.split(r'$');
    if (parts.length != 3 || parts[0] != _prefix) return false;
    return _hash(parts[1], pin) == parts[2];
  }

  @override
  Future<void> clear() async {
    try {
      await _writeStorage(null);
    } catch (_) {
      // The next read simply finds the old PIN again.
    }
  }

  /// The stored value, or null when there is none or it is unreadable.
  ///
  /// An unreadable value is treated as "no PIN", not as "wrong PIN": a store
  /// that cannot be parsed would otherwise lock every attempt out with no way
  /// back, and the person can still sign in online.
  Future<String?> _read() async {
    try {
      final value = await _readStorage();
      if (value == null || value.isEmpty) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  String _newSalt() {
    final bytes = List<int>.generate(_saltBytes, (_) => _random.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt$pin')).toString();
}

/// A PIN store that keeps its value in memory only. The default in tests.
class InMemoryOfflinePinStore implements OfflinePinStore {
  InMemoryOfflinePinStore([this.pin]);

  String? pin;

  @override
  Future<bool> hasPin() async => pin != null;

  @override
  Future<void> save(String pin) async {
    if (!isValidOfflinePin(pin)) {
      throw ArgumentError.value(pin, 'pin', 'must be four digits');
    }
    this.pin = pin;
  }

  @override
  Future<bool> matches(String pin) async => this.pin != null && this.pin == pin;

  @override
  Future<void> clear() async => pin = null;
}
