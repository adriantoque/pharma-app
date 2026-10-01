import 'dart:async';

import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_store.dart';

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

  @override
  Stream<List<MedicineModel>> watchAll() async* {
    if (!silent) yield _sorted();
    yield* _controller.stream;
  }

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

  void dispose() {
    if (!_controller.isClosed) unawaited(_controller.close());
  }
}
