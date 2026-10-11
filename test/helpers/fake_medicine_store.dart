import 'dart:async';

import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_store.dart';
import 'package:pharmaguide/features/search/data/sync/sync_status.dart';
import 'package:pharmaguide/features/search/data/sync/sync_status_source.dart';

/// An in-memory [MedicineStore] for the provider tests.
///
/// Behaves like the real one in the ways the provider depends on: it emits the
/// whole list again on every change, and its writes are asynchronous, so a test
/// that checks the optimistic update before awaiting still proves the update was
/// painted first.
class FakeMedicineStore implements MedicineStore {
  FakeMedicineStore({List<MedicineModel> initial = const []})
      : _medicines = List.of(initial);

  final List<MedicineModel> _medicines;
  final StreamController<List<MedicineModel>> _controller =
      StreamController<List<MedicineModel>>.broadcast();

  final List<String> _operations = [];

  /// What the store was asked to do, in order, for asserting on the write side.
  List<String> get operations => List.unmodifiable(_operations);

  /// When set, the next write of any kind throws this instead of succeeding.
  Object? writeError;

  /// When true, the store never emits. Used to prove the provider reports
  /// "loading" rather than "empty" while a read is outstanding.
  bool silent = false;

  /// When set, [watchAll] fails with this instead of emitting, as a Firestore
  /// query does when the device cannot reach the network.
  Object? readError;

  @override
  Stream<List<MedicineModel>> watchAll() async* {
    if (readError != null) throw readError!;
    if (!silent) yield _sorted();
    yield* _controller.stream;
  }

  /// Fails every read with [error] from now on.
  void failReads(Object error) => readError = error;

  @override
  Future<void> setStock(MedicineModel medicine, int? stock) async {
    _operations.add('setStock ${medicine.name} -> $stock');
    if (writeError != null) throw writeError!;
    _replaceWhere(medicine, (item) => item.copyWith(stock: stock));
  }

  @override
  Future<void> setExpiry(MedicineModel medicine, DateTime? expiry) async {
    _operations.add('setExpiry ${medicine.name} -> $expiry');
    if (writeError != null) throw writeError!;
    _replaceWhere(medicine, (item) => item.copyWith(expiryDate: expiry));
  }

  @override
  Future<void> upsert(MedicineModel medicine) async {
    _operations.add('upsert ${medicine.name}');
    if (writeError != null) throw writeError!;
    _replaceWhere(medicine, (item) => medicine);
  }

  @override
  Future<void> upsertAll(Iterable<MedicineModel> medicines) async {
    _operations.add('upsertAll ${medicines.length}');
    if (writeError != null) throw writeError!;
    for (final medicine in medicines) {
      _replaceWhere(medicine, (item) => medicine);
    }
  }

  void _replaceWhere(
    MedicineModel target,
    MedicineModel Function(MedicineModel current) replace,
  ) {
    final index = _medicines.indexWhere((item) => item == target);
    if (index == -1) {
      _medicines.add(replace(target));
    } else {
      _medicines[index] = replace(_medicines[index]);
    }
    _emit();
  }

  /// Changes the list from outside, as another device editing it would.
  void emit(List<MedicineModel> medicines) {
    _medicines
      ..clear()
      ..addAll(medicines);
    _emit();
  }

  void _emit() {
    if (silent || _controller.isClosed) return;
    _controller.add(_sorted());
  }

  List<MedicineModel> _sorted() =>
      List.of(_medicines)..sort(MedicineModel.compareByNameThenPrice);

  /// Whether the provider disposed this store, which it must do when an account is
  /// signed out. Left off the class's declared interface on purpose: most tests
  /// have no interest in it, and this keeps them from having to stub a method they
  /// do not think about.
  bool disposed = false;

  void dispose() {
    disposed = true;
    if (!_controller.isClosed) unawaited(_controller.close());
  }
}

/// A [MedicineStore] that can report its own reachability, as the real ones do.
///
/// Separate from [FakeMedicineStore] because [SyncStatusSource] is opt-in: a store
/// with no server behind it should be able to say so by simply not implementing it,
/// and a fake that implemented it everywhere would stop proving that.
class FakeSyncingMedicineStore extends FakeMedicineStore
    implements SyncStatusSource {
  FakeSyncingMedicineStore({super.initial, SyncStatus? status})
      : _status = status ?? SyncStatus.localOnly;

  final StreamController<SyncStatus> _syncController =
      StreamController<SyncStatus>.broadcast();

  SyncStatus _status;

  /// The status a new subscriber is handed before any live update, so a test can
  /// pin the starting state without racing a broadcast controller.
  SyncStatus get status => _status;

  /// Reports a new status the way a snapshot or a transport failure would.
  void report(SyncStatus status) {
    _status = status;
    if (!_syncController.isClosed) _syncController.add(status);
  }

  @override
  Stream<SyncStatus> watchSyncStatus() async* {
    yield _status;
    yield* _syncController.stream;
  }
}
