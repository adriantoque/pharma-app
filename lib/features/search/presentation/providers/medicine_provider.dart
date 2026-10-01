import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/medicine_model.dart';
import '../../data/repositories/medicine_repository.dart';
import '../../data/repositories/medicine_store.dart';
import '../../data/sync/sync_status.dart';
import '../../data/sync/sync_status_source.dart';

/// The live price list, held for the signed-in user.
///
/// Implements [MedicineRepository] as well as carrying the subscription, so the
/// prescription matcher can be pointed straight at this: the matcher needs a
/// snapshot of the catalogue, and re-reading the provider gives it the same
/// lines the dashboard is showing rather than a second, possibly older copy.
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
  StreamSubscription<SyncStatus>? _syncSubscription;
  MedicineStore? _store;

  /// How the catalogue relates to the server right now.
  ///
  /// Read by the offline banner above the navigation bar. Lives here rather than
  /// in a provider of its own because this class already owns the store, and the
  /// store is created per signed-in account -- a second provider would have to
  /// reach in here to reach it.
  ///
  /// Starts as [SyncStatus.unknown], not as online. Before the first snapshot
  /// nothing has been measured, and claiming a working connection the app has not
  /// tested is precisely the cheerful green tick that hides a dead one. A store
  /// that cannot report a status at all is a different case and is given
  /// [SyncStatus.localOnly]: the bundled catalogue and the static list have no
  /// server to lose, so reporting unknown forever would leave a banner on screen
  /// saying nothing useful.
  SyncStatus _syncStatus = SyncStatus.unknown;

  SyncStatus get syncStatus => _syncStatus;

  /// The account the current [_store] was built for.
  ///
  /// Tracked rather than inferred from whether a store exists, because a store
  /// being non-null says nothing about *whose* it is.
  String? _uid;

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
    // Unmodifiable on both paths, including the empty query a search box shows
    // before anything is typed. Returning the live list there would let a screen
    // that sorts its results reorder the provider's own catalogue in place.
    if (query.trim().isEmpty) return List.unmodifiable(_medicines);
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
      _releaseStore();
      _uid = null;
      _replace(const [], loading: false);
      return;
    }

    // Auth also fires while a cold start is still resolving, and rebuilding the
    // subscription on each of those events would throw away a catalogue that had
    // already loaded. Only a *different* user is worth reacting to -- a refresh
    // of the same account must leave what is already on screen alone.
    if (_uid == user.id) return;

    // A different user, and not via a sign-out: on a shared counter tablet the
    // session can be replaced underneath the app. The old subscription is
    // cancelled first, or the previous account's catalogue can still arrive and
    // land in this one's screen -- the exact leak the class doc warns about.
    _subscription?.cancel();
    _subscription = null;
    _releaseStore();
    _uid = user.id;

    _isLoading = true;
    _error = null;
    _replace(const [], loading: true);

    final store = _storeFor(user.id);
    _store = store;

    // Held separately from [_store], which is typed as the plain interface: this
    // is where a store that can report its own reachability gets noticed. A store
    // that cannot reports nothing and has nothing to lose either, so it is given
    // the local-only answer instead of being left on an unknown that never ends.
    switch (store) {
      case final SyncStatusSource source:
        _syncStatus = SyncStatus.unknown;
        _watchSyncStatus(source);
      case _:
_syncStatus = SyncStatus.unknown;
    }
    _subscription = store.watchAll().listen(
          _replace,
          onError: (Object error, StackTrace stackTrace) {
            _isLoading = false;
            _error = _describe(error);
            _safeNotify();
          },
        );
  }

  /// Follows how [source] is getting on with its server.
  ///
  /// Cancels the previous store's stream first, so a subscription belonging to an
  /// account that has been signed out cannot report into the new one's banner.
  void _watchSyncStatus(SyncStatusSource source) {
    _syncSubscription?.cancel();
    _syncSubscription = null;

    _syncSubscription = source.watchSyncStatus().listen((status) {
      if (_syncStatus == status) return;
      _syncStatus = status;
      _safeNotify();
    });
  }

  /// Lets go of the current store: its catalogue stream, its sync stream, and the
  /// resources behind it.
  ///
  /// The store is built per signed-in account and a shared counter tablet is
  /// signed in and out all day, so without this each session would leave a stream
  /// controller and its listeners behind for as long as the process lived.
  void _releaseStore() {
    _subscription?.cancel();
    _subscription = null;
    _syncSubscription?.cancel();
    _syncSubscription = null;

    final store = _store;
    _store = null;
    if (store case final DisposableStore disposable) disposable.dispose();

    _syncStatus = SyncStatus.localOnly;
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
  ///
  /// A count typed with no connection does *not* fail. The store queues it and
  /// resolves straight away, so the optimistic value stands and the offline
  /// banner is what says it is not on the server yet. Only a write the store
  /// actually rejects -- refused by the security rules, say -- is rolled back.
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
      _clearError();
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
      _clearError();
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
      _clearError();
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

  /// Drops a stale error after a write that worked.
  ///
  /// Notifies only when there was something to drop, so a routine stock count
  /// does not cost a second rebuild of every screen watching this provider.
  void _clearError() {
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
    _releaseStore();
    super.dispose();
  }
}
