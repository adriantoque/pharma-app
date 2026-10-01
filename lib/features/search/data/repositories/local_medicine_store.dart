import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicine_model.dart';
import '../sync/sync_status.dart';
import '../sync/sync_status_source.dart';
import 'bundled_medicine_source.dart';
import 'medicine_store.dart';

/// A price list that lives entirely on this device, with an overlay for edits.
///
/// Built for the "Continue offline" flow: the base catalogue comes from a
/// [MedicineSource] (the bundled seed in the app), and any stock counts or
/// expiry dates typed while offline are stored in SharedPreferences under
/// a fixed key. A store rebuilt after a restart re-applies that overlay, so the
/// pharmacist sees every edit they made before killing the app.
///
/// The overlay keeps only changed fields per document id. A line nobody touched
/// remains exactly as it came out of the bundle, so `isStockUnknown` stays true
/// for the rest of the price list -- a key distinction from overwriting every
/// document with null stock.
class LocalMedicineStore
    implements MedicineStore, SyncStatusSource, DisposableStore {
  LocalMedicineStore({
    MedicineSource? bundled,
    Future<SharedPreferences>? prefs,
  })  : _bundled = bundled ?? BundledMedicineSource(),
        _prefsFuture = prefs ?? SharedPreferences.getInstance();

  static const String _overlayKey = 'offlineMedicinesOverlay';

  final MedicineSource _bundled;
  final Future<SharedPreferences> _prefsFuture;

  final StreamController<List<MedicineModel>> _controller =
      StreamController<List<MedicineModel>>.broadcast();

  Future<List<MedicineModel>>? _basePending;

  /// The edits made on this device, keyed by document id.
  ///
  /// Mutable rather than `const {}` because a write adds a key to it; the empty
  /// instance is only ever the starting point, and a read never hands it out.
  Map<String, Map<String, dynamic>> _overlay = {};
  bool _loaded = false;
  bool _disposed = false;

  Future<List<MedicineModel>> _loadBase() =>
      _basePending ??= _bundled.load().catchError((Object _) => const <MedicineModel>[]);

  Future<void> _init() async {
    if (_loaded) return;
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_overlayKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        _overlay = {};
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final patch = entry.value;
            if (patch is Map) {
              _overlay['${entry.key}'] = Map<String, dynamic>.from(patch);
            }
          }
        }
      } catch (_) {
        // A payload that will not decode is a store this device cannot read, not
        // a reason to leave the price list blank: the bundled list is still
        // there, and the pharmacist can retype the few counts they cared about.
        _overlay = {};
      }
    }
    _loaded = true;
  }

  Future<void> _persistOverlay() async {
    final prefs = await _prefsFuture;
    try {
      await prefs.setString(
        _overlayKey,
        jsonEncode(_overlay.map((key, value) => MapEntry(key, value))),
      );
    } catch (_) {
      // Ignored: persistence is best-effort and the in-memory overlay is
      // already the source of truth for the current session.
    }
  }

  List<MedicineModel> _applyOverlay(List<MedicineModel> base) {
    if (_overlay.isEmpty) return List.unmodifiable(base);
    final byId = <String, MedicineModel>{for (final m in base) m.documentId: m};
    for (final entry in _overlay.entries) {
      final id = entry.key;
      final patch = entry.value;
      final existing = byId[id];
      if (existing == null) continue;
      int? stock;
      DateTime? expiry;
      if (patch.containsKey('stock')) {
        stock = (patch['stock'] is int)
            ? patch['stock'] as int
            : (patch['stock'] as num?)?.round();
      }
      if (patch.containsKey('expiryDate')) {
        final v = patch['expiryDate'];
        expiry = v is String ? _parseDate(v) : null;
      }
      byId[id] = existing.copyWith(
        stock: patch.containsKey('stock') ? stock : existing.stock,
        expiryDate: patch.containsKey('expiryDate')
            ? expiry
            : existing.expiryDate,
      );
    }
    final merged = byId.values.toList()
      ..sort(MedicineModel.compareByNameThenPrice);
    return List.unmodifiable(merged);
  }

  @override
  Stream<List<MedicineModel>> watchAll() async* {
    await _init();
    final base = await _loadBase();
    yield _applyOverlay(base);
    yield* _controller.stream;
  }

  void _emit() async {
    if (_disposed) return;
    await _init();
    final base = await _loadBase();
    if (!_controller.isClosed) {
      _controller.add(_applyOverlay(base));
    }
  }

  @override
  Future<void> setStock(MedicineModel medicine, int? stock) async {
    await _init();
    final id = medicine.documentId;
    final patch = _overlay.putIfAbsent(id, () => <String, dynamic>{});
    patch['stock'] = stock;
    await _persistOverlay();
    _emit();
  }

  @override
  Future<void> setExpiry(MedicineModel medicine, DateTime? expiry) async {
    await _init();
    final id = medicine.documentId;
    final patch = _overlay.putIfAbsent(id, () => <String, dynamic>{});
    patch['expiryDate'] = MedicineModel.formatExpiry(expiry);
    await _persistOverlay();
    _emit();
  }

  @override
  Future<void> upsert(MedicineModel medicine) async {
    await _init();
    final id = medicine.documentId;
    final patch = _overlay.putIfAbsent(id, () => <String, dynamic>{});
    patch['stock'] = medicine.stock;
    patch['expiryDate'] = MedicineModel.formatExpiry(medicine.expiryDate);
    await _persistOverlay();
    _emit();
  }

  @override
  Future<void> upsertAll(Iterable<MedicineModel> medicines) async {
    await _init();
    for (final m in medicines) {
      final id = m.documentId;
      final patch = _overlay.putIfAbsent(id, () => <String, dynamic>{});
      patch['stock'] = m.stock;
      patch['expiryDate'] = MedicineModel.formatExpiry(medicineExpiry(m, m.expiryDate));
    }
    await _persistOverlay();
    _emit();
  }

  static DateTime? medicineExpiry(MedicineModel m, DateTime? e) => e;

  static DateTime? _parseDate(String value) {
    final date = value.split(RegExp('[T ]')).first;
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  @override
  Stream<SyncStatus> watchSyncStatus() => Stream<SyncStatus>.value(SyncStatus.localOnly);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_controller.close());
  }
}
