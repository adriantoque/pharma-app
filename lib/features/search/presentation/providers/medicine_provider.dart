import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/medicine_model.dart';
import '../../data/repositories/medicine_repository.dart';
import '../../data/repositories/medicine_store.dart';

/// The live price list, held for the signed-in user.
///
/// Implements [MedicineRepository] as well as carrying the subscription, so the
/// prescription matcher can be pointed straight at this: the matcher needs a
/// snapshot of the catalogue, and re-reading the provider gives it the same
/// lines the search screen is showing rather than a second, possibly older copy.
class MedicineProvider extends ChangeNotifier implements MedicineRepository {
  /// [storeFor] is a factory rather than a store because the store is scoped to
  /// a user id that only exists once sign-in has resolved, and it has to be
  /// rebuilt when that user changes: a shared counter tablet is signed in and out
  /// all day, and a store still pointed at the previous account would either
  /// throw or, worse, quietly keep showing the last user's catalogue.
  MedicineProvider({
    required AuthProvider auth,
    required MedicineStore Function(String uid) storeFor,
  }) {
    _auth = auth;
    _storeFor = storeFor;
    auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  AuthProvider? _auth;
  late final MedicineStore Function(String uid) _storeFor;

  StreamSubscription<List<MedicineModel>>? _subscription;
  MedicineStore? _store;

  List<MedicineModel> _medicines = const [];
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  /// True while the first read of the catalogue is outstanding.
  ///
  /// Distinct from "the list is empty": an empty pharmacy is not a state this
  /// app has to handle specially, whereas a first read that has not landed is,
  /// and showing an empty price list during it would read as "the pharmacy
  /// stocks nothing".
  bool get isLoading => _isLoading;

  /// Why the catalogue could not be read, or null if it is simply empty.
  String? get error => _error;

  bool get isEmpty => _medicines.isEmpty;

  @override
  List<MedicineModel> all() => _medicines;

  @override
  List<MedicineModel> search(String query) {
    if (query.trim().isEmpty) return _medicines;
    final results = _medicines.where((item) => item.matches(query)).toList()
      ..sort(MedicineModel.compareByNameThenPrice);
    return List.unmodifiable(results);
  }

  /// Drops the previous account's catalogue rather than leaving it on screen for
  /// the seconds before the login route paints. The subscription is cancelled
  /// before the list is cleared so an in-flight event cannot repopulate it.
  void _onAuthChanged() {
    final user = _auth?.user;
    if (user == null) {
      _subscription?.cancel();
      _subscription = null;
      _store = null;
      _replace(const [], loading: false);
      return;
    }

    // Auth also fires while a cold start is still resolving, and rebuilding the
    // subscription on each of those events would throw away a catalogue that had
    // already loaded. Only a change of user is worth reacting to.
    if (_store != null) {
      return;
    }

    _isLoading = true;
    _error = null;
    _safeNotify();

    final store = _storeFor(user.id);
    _store = store;
    _subscription = store.watchAll().listen(
          _replace,
          onError: (Object error, StackTrace stackTrace) {
            _isLoading = false;
            _error = _describe(error);
            _safeNotify();
          },
        );
  }

  void _replace(List<MedicineModel> medicines, {bool? loading}) {
    _medicines = medicines;
    if (loading != null) {
      _isLoading = loading;
    } else if (_error == null) {
      // A stream emission means the read worked, so the spinner comes down even
      // if a previous write had failed. The error is left alone, because a
      // failed write is still worth showing and the next successful read does
      // not undo it.
      _isLoading = false;
    }
    _safeNotify();
  }

  /// Records a stock count, showing the new value at once.
  ///
  /// The list is updated locally before the write goes out, because a count
  /// typed at the counter should not appear to have been refused while a round
  /// trip completes. If the write fails the change is rolled back to the value
  /// Firestore last confirmed, and the error is surfaced -- a count that silently
  /// did not save is how a shelf and the app drift apart for a month.
  Future<void> setStock(MedicineModel medicine, int? stock) async {
    final store = _store;
    if (store == null) return;

    final previous = _medicines;
    _replace(
      [
        for (final item in _medicines)
          if (item == medicine) item.copyWith(stock: stock) else item,
      ],
    );

    try {
      await store.setStock(medicine, stock);
      _error = null;
    } catch (error) {
      _replace(previous);
      _error = _describe(error);
      _safeNotify();
    }
  }

  /// Records or clears an expiry date. Rolls back and reports the same way as
  /// [setStock].
  Future<void> setExpiry(MedicineModel medicine, DateTime? expiry) async {
    final store = _store;
    if (store == null) return;

    final previous = _medicines;
    _replace([
      for (final item in _medicines)
        if (item == medicine) item.copyWith(expiryDate: expiry) else item,
    ]);

    try {
      await store.setExpiry(medicine, expiry);
      _error = null;
    } catch (error) {
      _replace(previous);
      _error = _describe(error);
      _safeNotify();
    }
  }

  /// Writes an imported price list in, for the account currently signed in.
  Future<void> importMedicines(Iterable<MedicineModel> medicines) async {
    final store = _store;
    if (store == null) return;
    try {
      await store.upsertAll(medicines);
    } catch (error) {
      _error = _describe(error);
      _safeNotify();
    }
  }

  /// Clears a reported error, once a screen has shown it.
  void clearError() {
    if (_error == null) return;
    _error = null;
    _safeNotify();
  }

  /// Turns a Firestore error into something a pharmacist can act on.
  ///
  /// The common one by a distance is a missing Firestore database, which arrives
  /// as a `FirebaseException` whose message is a URL and a code. Reading that at
  /// the counter helps nobody, so it is translated here.
  static String _describe(Object error) {
    final text = error.toString();
    if (text.contains('PERMISSION_DENIED')) {
      return 'Firestore refused the request. Check the security rules allow this '
          'account to read its own catalogue.';
    }
    if (text.contains('NOT_FOUND') || text.contains('does not exist')) {
      return 'Firestore is not set up for this project yet. Create the database '
          'in the Firebase console, then sign out and back in.';
    }
    if (text.contains('UNAVAILABLE') || text.contains('network')) {
      return 'Could not reach Firestore. Check the connection and try again.';
    }
    return text
        .replaceFirst(
          RegExp(r'^(Exception|Bad state|PlatformException|Unsupported error):\s*'),
          '',
        )
        .trim();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    // Flipped before the listener is removed, for the same reason as the other
    // providers: a cancelled subscription can still deliver one last event.
    _disposed = true;
    _auth?.removeListener(_onAuthChanged);
    _auth = null;
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
