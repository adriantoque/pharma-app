import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/medicine_model.dart';

/// Somewhere a price list can be read from that is not a server.
///
/// An interface rather than a concrete class so the offline store can be handed a
/// list in a test instead of the bundled asset. That is not only tidier than
/// reaching into `rootBundle`: the asset is 148KB of JSON, and a widget test that
/// decoded it once per test would cost more than every other test in the suite
/// put together.
abstract interface class MedicineSource {
  /// The whole price list, or an empty list if there is nothing to read.
  Future<List<MedicineModel>> load();
}

/// The price list shipped inside the app binary.
///
/// The same file `tool/import_sales_tracker.dart` writes and
/// `tool/seed_firestore.dart` uploads, so the fallback and the server agree on
/// what the pharmacy stocks. Every line in it carries a null stock count, because
/// the source was a price list with no quantities on it: the app must not invent
/// one. An uncounted line is still orderable, capped at
/// [OrderProvider.maxQuantity], so this is a working price list rather than a
/// degraded one.
class BundledMedicineSource implements MedicineSource {
  BundledMedicineSource({this.assetPath = defaultAssetPath});

  static const String defaultAssetPath = 'assets/data/medicines_seed.json';

  final String assetPath;

  /// The read in flight or already done, so concurrent callers share one pass
  /// over the asset instead of each decoding their own copy.
  Future<List<MedicineModel>>? _pending;

  @override
  Future<List<MedicineModel>> load() {
    final existing = _pending;
    if (existing != null) return existing;

    final pending = _read();
    _pending = pending;

    // A failed read is not remembered. The asset is inside the binary and cannot
    // become readable later, but a decode failure cached for the life of the
    // process would leave the catalogue permanently blank with no way to retry.
    pending.then((_) {}, onError: (Object _) {
      if (identical(_pending, pending)) _pending = null;
    });

    return pending;
  }

  Future<List<MedicineModel>> _read() async {
    final decoded = jsonDecode(await rootBundle.loadString(assetPath));
    if (decoded is! List) return const [];

    final entries = decoded.whereType<Map<String, dynamic>>();
    final items = <MedicineModel>[
      // Read through the same lenient parser Firestore documents go through, so a
      // malformed line becomes an uncounted line rather than taking the whole
      // catalogue down with it.
      for (final entry in entries) MedicineModel.fromFirestore(entry),
    ]..sort(MedicineModel.compareByNameThenPrice);

    return List.unmodifiable(items);
  }
}

/// A price list handed over directly, for tests and for a future local-only mode.
class ListMedicineSource implements MedicineSource {
  ListMedicineSource(Iterable<MedicineModel> medicines)
    : _medicines = _sorted(medicines);

  final List<MedicineModel> _medicines;

  int loadCount = 0;

  @override
  Future<List<MedicineModel>> load() async {
    loadCount++;
    return _medicines;
  }

  /// Sorted through a typed list, because a collection literal in an initializer
  /// has no type to sort against and falls back to `dynamic` comparisons.
  static List<MedicineModel> _sorted(Iterable<MedicineModel> medicines) {
    final items = List<MedicineModel>.of(medicines)
      ..sort(MedicineModel.compareByNameThenPrice);
    return List.unmodifiable(items);
  }
}