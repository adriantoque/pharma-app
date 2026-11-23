// Fakes for the search feature's store tests.
//
// The real stores talk to Firestore and SQLite; these talk to lists and
// records, so a store's *logic* -- merge, mirror, rollback, seeding -- can be
// driven without a server, a database or a network. The shapes follow the
// interfaces exactly, and anything the fakes cannot express is a sign the
// interface needs a second look rather than of a weak test.
library;

import 'dart:async';

import 'package:pharmaguide/features/search/data/local/medicine_cache.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_store.dart';
import 'package:pharmaguide/features/search/data/sync/pending_write_reporting.dart';
import 'package:pharmaguide/features/search/data/sync/sync_status.dart';
import 'package:pharmaguide/features/search/data/sync/sync_status_source.dart';

/// A price list held in a map, standing in for the SQLite cache.
///
/// Writes that fail are failures the *test* chose: [refuseWrites] makes every
/// write throw, which is how a refusal from the security rules is simulated
/// without a Firestore.
class FakeMedicineCache implements MedicineCache {
  final Map<String, MedicineModel> _rows = {};

  /// Every write, in order, so a test can assert what reached the cache.
  final List<String> operations = [];

  /// When true, every write throws instead of applying.
  bool refuseWrites = false;

  /// How many times the whole cache has been read.
  int loadCount = 0;

  void seedAll(Iterable<MedicineModel> medicines) {
    for (final medicine in medicines) {
      _rows[medicine.documentId] = medicine;
    }
  }

  @override
  Future<List<MedicineModel>> loadAll() async {
    loadCount++;
    final medicines = List.of(_rows.values)
      ..sort(MedicineModel.compareByNameThenPrice);
    return List.unmodifiable(medicines);
  }

  @override
  Future<MedicineModel?> findById(String documentId) async => _rows[documentId];

  @override
  Stream<List<MedicineModel>> watchAll() async* {
    // One shot rather than live: the synced store reads the cache through
    // [loadAll], so a live stream here would be wiring nothing uses.
    yield await loadAll();
  }

  @override
  Future<void> deleteById(String documentId) async {
    operations.add('delete/$documentId');
    if (refuseWrites) throw StateError('cache refused');
    _rows.remove(documentId);
  }

  @override
  Future<void> setStock(MedicineModel medicine, int? stock) async {
    operations.add('setStock/${medicine.documentId}/$stock');
    if (refuseWrites) throw StateError('cache refused');
    _patch(medicine.documentId, (current) => current.copyWith(stock: stock));
  }

  @override
  Future<void> setExpiry(MedicineModel medicine, DateTime? expiry) async {
    operations.add('setExpiry/${medicine.documentId}');
    if (refuseWrites) throw StateError('cache refused');
    _patch(medicine.documentId, (current) => current.copyWith(expiryDate: expiry));
  }

  @override
  Future<void> upsert(MedicineModel medicine) async {
    operations.add('upsert/${medicine.documentId}');
    if (refuseWrites) throw StateError('cache refused');
    _rows[medicine.documentId] = medicine;
  }

  @override
  Future<void> upsertAll(Iterable<MedicineModel> medicines) async {
    operations.add('upsertAll/${medicines.length}');
    if (refuseWrites) throw StateError('cache refused');
    seedAll(medicines);
  }

  void _patch(String id, MedicineModel Function(MedicineModel) change) {
    final current = _rows[id];
    if (current == null) return;
    _rows[id] = change(current);
  }

  MedicineModel? operator [](String documentId) => _rows[documentId];

  bool contains(String documentId) => _rows.containsKey(documentId);
}

/// A price list server that the test drives by hand.
///
/// The stream does nothing until [emit] or [emitError] is called, which is the
/// point: a snapshot arrives when the test says one arrives, so ordering and
/// stale-over-pending behaviour can be staged rather than raced.
class FakeRemoteMedicineStore
    implements MedicineStore, PendingWriteReporting, SyncStatusSource {
  final StreamController<List<MedicineModel>> _controller =
      StreamController<List<MedicineModel>>();

  /// Every write, in order.
  final List<String> operations = [];

  /// The documents the server has not acknowledged, as the test says.
  Set<String> pending = {};

  /// The next write throws with this when it is set, and it is consumed.
  ///
  /// A thrown write is how a refusal from the security rules is simulated: the
  /// real store swallows transport failures and rethrows refusals, so a throw
  /// is exactly the refusal case.
  Object? writeError;

  /// What the server would answer with, for the tests that read it back.
  final Map<String, MedicineModel> stored = {};

  void emit(List<MedicineModel> medicines) {
    _controller.add(List.unmodifiable(medicines));
  }

  void emitError(Object error) {
    _controller.addError(error, StackTrace.current);
  }

  @override
  Stream<List<MedicineModel>> watchAll() => _controller.stream;

  @override
  Set<String> get pendingDocumentIds => pending;

  void _maybeRefuse() {
    final error = writeError;
    if (error == null) return;
    writeError = null;
    Error.throwWithStackTrace(error, StackTrace.current);
  }

  @override
  Future<void> setStock(MedicineModel medicine, int? stock) async {
    operations.add('setStock/${medicine.documentId}/$stock');
    _maybeRefuse();
    stored[medicine.documentId] = medicine.copyWith(stock: stock);
  }

  @override
  Future<void> setExpiry(MedicineModel medicine, DateTime? expiry) async {
    operations.add('setExpiry/${medicine.documentId}');
    _maybeRefuse();
    stored[medicine.documentId] = medicine.copyWith(expiryDate: expiry);
  }

  @override
  Future<void> upsert(MedicineModel medicine) async {
    operations.add('upsert/${medicine.documentId}');
    _maybeRefuse();
    stored[medicine.documentId] = medicine;
  }

  @override
  Future<void> upsertAll(Iterable<MedicineModel> medicines) async {
    operations.add('upsertAll/${medicines.length}');
    _maybeRefuse();
    for (final medicine in medicines) {
      stored[medicine.documentId] = medicine;
    }
  }

  @override
  Stream<SyncStatus> watchSyncStatus() => Stream<SyncStatus>.value(
    SyncStatus(reachability: Reachability.online),
  );
}

/// Lets a test read a store's emissions the way the provider does.
extension StoreStreamRecorder on Stream<List<MedicineModel>> {
  Future<(List<List<MedicineModel>>, List<Object>)> record(
    int turns,
  ) async {
    final events = <List<MedicineModel>>[];
    final errors = <Object>[];
    final subscription = listen(
      events.add,
      onError: errors.add,
    );
    for (var i = 0; i < turns; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await subscription.cancel();
    return (events, errors);
  }
}

