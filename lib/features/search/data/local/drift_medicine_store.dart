/// The price list on disk, backed by the [AppDatabase].
///
/// Implements [MedicineCache] over SQLite. It fills three roles at once:
///
/// - the catalogue behind **deliberate offline mode**: the base price list is
///   seeded from the bundled JSON on first open, and edits are rows, so a
///   restart re-reads them without an overlay to re-apply;
/// - the **durable cache** behind [SyncedMedicineStore] for online users, which
///   mirrors the server's answer into the same rows;
/// - the **migration path** for an upgrade from the previous build, whose
///   offline edits lived in a SharedPreferences overlay under
///   `offlineMedicinesOverlay`.
///
/// One row per price-list line, keyed by [MedicineModel.documentId], so a
/// re-seed and a mirror both update in place instead of duplicating. Partial
/// writes (`stock` alone, `expiryDate` alone) are partial in SQL too, so a
/// mirror or a concurrent edit cannot be clobbered by a stale copy of a row.
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicine_model.dart';
import '../repositories/bundled_medicine_source.dart';
import '../sync/sync_status.dart';
import '../sync/sync_status_source.dart';
import 'app_database.dart';
import 'medicine_cache.dart';
import 'medicine_row_codec.dart';

class DriftMedicineStore
    implements MedicineCache, SyncStatusSource, DisposableStore {
  DriftMedicineStore({
    required AppDatabase database,
    MedicineSource? bundled,
    Future<SharedPreferences>? prefs,
  })  : // A named parameter cannot be private, so `this._database` is not
       // available and this is the only shape it can take.
       // ignore: prefer_initializing_formals
       _database = database,
       _bundled = bundled ?? BundledMedicineSource(),
       _prefsFuture = prefs ?? SharedPreferences.getInstance();

  /// The SharedPreferences key the previous build stored offline edits under.
  ///
  /// Read once during first seeding, applied to the rows, then deleted. Kept
  /// here rather than left in the old store's file so the migration can be
  /// deleted when it has been shipped for a release cycle.
  static const String _overlayKey = 'offlineMedicinesOverlay';

  final AppDatabase _database;
  final MedicineSource _bundled;
  final Future<SharedPreferences> _prefsFuture;

  /// The seeding in flight or already done, so every caller waits for the same
  /// pass instead of racing each other to an empty catalogue.
  Future<void>? _seeding;
  bool _disposed = false;

  /// Reads the catalogue, seeding it first if the database is empty.
  ///
  /// The first call pays for opening the database, the seed and the overlay
  /// migration; later calls are a single query.
  @override
  Future<List<MedicineModel>> loadAll() async {
    await _ensureSeeded();
    if (_disposed) return const [];
    return _readAll();
  }

  Future<List<MedicineModel>> _readAll() async {
    final rows = await _database.allMedicines();
    final medicines = [for (final row in rows) medicineFromRow(row)]
      ..sort(MedicineModel.compareByNameThenPrice);
    return List.unmodifiable(medicines);
  }

  @override
  Future<MedicineModel?> findById(String documentId) async {
    await _ensureSeeded();
    final row = await _database.findMedicine(documentId);
    return row == null ? null : medicineFromRow(row);
  }

  @override
  Stream<List<MedicineModel>> watchAll() {
    // A controller rather than an `async*` generator over `await for`. An
    // async* generator suspended in `await for` deadlocks on cancellation
    // over a drift watch stream: the generator's finalization awaits the
    // inner subscription's cancel, which never completes in that state --
    // found with a probe, after the raw subscription cancelled fine. A
    // controller cancels the inner subscription explicitly in [onCancel],
    // which the price-list provider does on every account switch, so the
    // difference is not academic.
    StreamSubscription<List<MedicineRow>>? subscription;
    late final StreamController<List<MedicineModel>> controller;

    Future<void> start() async {
      await _ensureSeeded();
      if (controller.isClosed) return;
      subscription = _database.watchMedicines().listen((rows) {
        final medicines = [for (final row in rows) medicineFromRow(row)]
          ..sort(MedicineModel.compareByNameThenPrice);
        controller.add(List.unmodifiable(medicines));
      });
    }

    controller = StreamController<List<MedicineModel>>(
      onListen: () {
        start().catchError((Object _) {
          // Seeding already decided that a failed seed is not fatal; the
          // same tolerance applies to the subscription that shows it.
        });
      },
      onCancel: () => subscription?.cancel() ?? Future<void>.value(),
    );
    return controller.stream;
  }

  @override
  Future<void> setStock(MedicineModel medicine, int? stock) async {
    await _ensureSeeded();
    // Only the count, for the same reason the Firestore store merges one field:
    // a full-row write here would let a count typed on the inventory screen
    // overwrite an expiry a mirror brought in a moment earlier.
    await _database.updateStock(medicine.documentId, stock);
  }

  @override
  Future<void> setExpiry(MedicineModel medicine, DateTime? expiry) async {
    await _ensureSeeded();
    await _database.updateExpiry(
      medicine.documentId,
      MedicineModel.formatExpiry(expiry),
    );
  }

  @override
  Future<void> upsert(MedicineModel medicine) async {
    await _ensureSeeded();
    await _database.writeMedicine(rowFromMedicine(medicine));
  }

  @override
  Future<void> upsertAll(Iterable<MedicineModel> medicines) async {
    await _ensureSeeded();
    // Timestamped once per import rather than per row: the whole batch is one
    // fact about the catalogue, not one fact per line.
    final updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _database.writeMedicines([
      for (final medicine in medicines) rowFromMedicine(medicine, updatedAt: updatedAt),
    ]);
  }

  @override
  Future<void> deleteById(String documentId) async {
    await _ensureSeeded();
    await _database.deleteMedicine(documentId);
  }

  @override
  Stream<SyncStatus> watchSyncStatus() => Stream<SyncStatus>.value(
    SyncStatus.localOnly,
  );

  /// Seeds the catalogue from the bundle the first time, and carries any
  /// offline edits the previous build kept in SharedPreferences across.
  ///
  /// Deliberately tolerant: an unreadable asset, an unreadable overlay and a
  /// write that fails are all reasons to keep going with what the database
  /// already holds, because a price list that shows is worth more than one
  /// that throws. The one thing it does not do is seed twice -- the guard is
  /// the [AppDatabase] being empty, and a non-empty database means somebody
  /// (a previous run, the mirror) has already written the truth.
  Future<void> _ensureSeeded() => _seeding ??= _seed();

  Future<void> _seed() async {
    try {
      final existing = await _database.allMedicines();
      if (existing.isNotEmpty) return;

      final base = await _bundled
          .load()
          .catchError((Object _) => const <MedicineModel>[]);
      if (base.isEmpty) return;
      // Written to the database directly rather than through [upsertAll]:
      // every write method here waits for seeding, and seeding is what is
      // running -- calling one of them would await the very future it is
      // inside, and the first launch would hang forever.
      final updatedAt = DateTime.now().millisecondsSinceEpoch;
      await _database.writeMedicines([
        for (final medicine in base) rowFromMedicine(medicine, updatedAt: updatedAt),
      ]);
      await _migrateOverlay(base);
    } catch (_) {
      // A seed that cannot finish is not fatal: whatever the database already
      // holds is shown, and the next open gets the same chance. The reads and
      // writes the callers make afterwards still surface a real failure.
    }
  }

  /// Applies the previous build's offline edits and deletes the key.
  ///
  /// The overlay keyed lines by [MedicineModel.documentId]; older builds keyed
  /// them by [MedicineModel.legacyDocumentId], which is why the bundle is
  /// needed to translate. An id no row answers to is left alone: it belongs to
  /// a line the bundle no longer carries, and inventing a row for it would put
  /// a phantom medicine on the shelf.
  Future<void> _migrateOverlay(List<MedicineModel> base) async {
    final prefs = await _prefsFuture;
    final overlay = _readOverlay(prefs);
    if (overlay.isEmpty) return;

    final legacyIds = <String, String>{
      for (final medicine in base)
        if (medicine.productId != null)
          medicine.legacyDocumentId: medicine.documentId,
    };

    for (final entry in overlay.entries) {
      final id = legacyIds[entry.key] ?? entry.key;
      final patch = entry.value;
      final hasStock = patch.containsKey('stock');
      final hasExpiry = patch.containsKey('expiryDate');
      if (!hasStock && !hasExpiry) continue;

      final existing = await _database.findMedicine(id);
      if (existing == null) continue;
      if (hasStock) {
        await _database.updateStock(id, _readStock(patch['stock']));
      }
      if (hasExpiry) {
        await _database.updateExpiry(id, _readExpiry(patch['expiryDate']));
      }
    }
    await prefs.remove(_overlayKey);
  }

  /// The overlay patches, in the shape the previous build wrote.
  Map<String, Map<String, dynamic>> _readOverlay(SharedPreferences prefs) {
    final raw = prefs.getString(_overlayKey);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map) '${entry.key}': Map<String, dynamic>.from(
            entry.value as Map,
          ),
      };
    } catch (_) {
      return const {};
    }
  }

  static int? _readStock(Object? value) => switch (value) {
    int v => v,
    num v => v.round(),
    String v => int.tryParse(v),
    _ => null,
  };

  /// The overlay already stored expiries as `yyyy-MM-dd` strings -- the same
  /// shape the column uses -- so the value is passed through as it stands.
  static String? _readExpiry(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  @override
  void dispose() {
    // Nothing to hand back: the [AppDatabase] is app-scoped and provided above
    // the router, and watchAll's subscription is held by its listener. Still
    // flagged, so a store that has been released stops emitting into the void.
    _disposed = true;
  }
}
