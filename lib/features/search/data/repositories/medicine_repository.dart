import '../models/medicine_model.dart';

abstract class MedicineRepository {
  /// The whole price list, ordered the way the list screen shows it.
  List<MedicineModel> all();

  /// Items matching [query]. An empty query returns everything.
  List<MedicineModel> search(String query);
}

/// Price list held in the binary.
///
/// Deliberately behind [MedicineRepository] so that moving it to Firestore later
/// is a new implementation of this interface rather than a change to the UI.
class StaticMedicineRepository implements MedicineRepository {
  const StaticMedicineRepository();

  /// Transcribed from the pharmacy's list. Names are verbatim, including the
  /// inconsistent capitalisation (`CARDO CAP` next to `Cloxacillin`) and the
  /// misspellings, because this is what the counter staff type and read.
  ///
  /// The `stock:` values are PLACEHOLDERS, not real counts -- the source data
  /// was a price list with no quantities on it. They are spread on purpose so
  /// every stock state is reviewable on screen: seven items are out of stock,
  /// nine are at or below [MedicineModel.lowStockThreshold], and the rest are
  /// healthy. Replace them with the real numbers in one pass; nothing else in
  /// the app hard-codes a level.
  ///
  /// `Alcohol` is seeded high because three tests assert the order's own
  /// 99-per-item ceiling is the binding limit, which is only true for an item
  /// holding more than 99.
  static const List<MedicineModel> _items = [
    MedicineModel(name: 'Alcohol', priceCentavos: 6500, stock: 240),
    MedicineModel(name: 'Alcohol med', priceCentavos: 6500, stock: 18),
    MedicineModel(name: 'Alcohol small', priceCentavos: 2200, stock: 0),
    MedicineModel(name: 'ALAGAD CAP', priceCentavos: 400, stock: 3),
    MedicineModel(name: 'Amox', priceCentavos: 400, stock: 96),
    MedicineModel(name: 'Amox', priceCentavos: 4500, stock: 0),
    MedicineModel(name: 'Amox 250 CAP', priceCentavos: 400, stock: 140),
    MedicineModel(name: 'Amox 500mg', priceCentavos: 400, stock: 2),
    MedicineModel(name: 'amplodiphine', priceCentavos: 300, stock: 55),
    MedicineModel(name: 'Ascorbic Tablet', priceCentavos: 300, stock: 120),
    MedicineModel(name: 'Baby Oil', priceCentavos: 3000, stock: 24),
    MedicineModel(name: 'BIOFLU', priceCentavos: 1100, stock: 7),
    MedicineModel(name: 'Biogesic', priceCentavos: 600, stock: 41),
    MedicineModel(name: 'calmosipten', priceCentavos: 5000, stock: 0),
    MedicineModel(name: 'CARDO CAP', priceCentavos: 400, stock: 5),
    MedicineModel(name: 'cefalexin', priceCentavos: 4500, stock: 33),
    MedicineModel(name: 'Cetirizine', priceCentavos: 400, stock: 88),
    MedicineModel(name: 'Cetirizine syrup', priceCentavos: 6000, stock: 12),
    MedicineModel(name: 'Cetirizine tab', priceCentavos: 300, stock: 64),
    MedicineModel(name: 'CINNARIZINE', priceCentavos: 300, stock: 29),
    MedicineModel(name: 'Cloxacillin', priceCentavos: 700, stock: 5),
    MedicineModel(name: 'decolgen', priceCentavos: 1000, stock: 47),
    MedicineModel(name: 'DIATABS', priceCentavos: 1100, stock: 21),
    MedicineModel(name: 'DIATABS', priceCentavos: 2200, stock: 4),
    MedicineModel(name: 'Diatabs', priceCentavos: 700, stock: 103),
    MedicineModel(name: 'efficasent', priceCentavos: 3500, stock: 15),
    MedicineModel(name: 'ElShadai', priceCentavos: 2000, stock: 38),
    MedicineModel(name: 'ENERVON', priceCentavos: 1200, stock: 72),
    MedicineModel(name: 'ERCEFLORA', priceCentavos: 5000, stock: 9),
    MedicineModel(name: 'EYEMO', priceCentavos: 10500, stock: 6),
    MedicineModel(name: 'Fern s syrup', priceCentavos: 16500, stock: 0),
    MedicineModel(name: 'FLANAX', priceCentavos: 2700, stock: 44),
    MedicineModel(name: 'GETERIZINE', priceCentavos: 250, stock: 130),
    MedicineModel(name: 'hivent', priceCentavos: 1800, stock: 26),
    MedicineModel(name: 'KATIALIS', priceCentavos: 3200, stock: 11),
    MedicineModel(name: 'Katinko', priceCentavos: 3800, stock: 52),
    MedicineModel(name: 'Katinko roll', priceCentavos: 5500, stock: 19),
    MedicineModel(name: 'lady pills', priceCentavos: 5500, stock: 0),
    MedicineModel(name: 'losartan', priceCentavos: 400, stock: 77),
    MedicineModel(name: 'Manzanil', priceCentavos: 2100, stock: 31),
    MedicineModel(name: 'Medicol', priceCentavos: 900, stock: 14),
    MedicineModel(name: 'Meffe', priceCentavos: 300, stock: 1),
    MedicineModel(name: 'MEFENAMIC', priceCentavos: 300, stock: 67),
    MedicineModel(name: 'naproxen', priceCentavos: 700, stock: 43),
    MedicineModel(name: 'nutriflex', priceCentavos: 32500, stock: 8),
    MedicineModel(name: 'off lotion', priceCentavos: 1300, stock: 35),
    MedicineModel(name: 'Omegaazole', priceCentavos: 1000, stock: 22),
    MedicineModel(name: 'Para syrup', priceCentavos: 4800, stock: 27),
    MedicineModel(name: 'paracetamol 125', priceCentavos: 4500, stock: 3),
    MedicineModel(name: 'pharex', priceCentavos: 600, stock: 61),
    MedicineModel(name: 'PT', priceCentavos: 4500, stock: 16),
    MedicineModel(name: 'PYROFLORA', priceCentavos: 3500, stock: 39),
    MedicineModel(name: 'Salbutamol 4mg', priceCentavos: 300, stock: 2),
    MedicineModel(name: 'salompas', priceCentavos: 4700, stock: 48),
    MedicineModel(name: 'SUPPOSITORY', priceCentavos: 1900, stock: 25),
    MedicineModel(name: 'symdex', priceCentavos: 8000, stock: 13),
    MedicineModel(name: 'Tempra 1-5', priceCentavos: 13500, stock: 0),
    MedicineModel(name: 'Tramadol', priceCentavos: 400, stock: 94),
    MedicineModel(name: 'Tramadol', priceCentavos: 1000, stock: 4),
    MedicineModel(name: 'Tramadol', priceCentavos: 1300, stock: 57),
    MedicineModel(name: 'Trust pills', priceCentavos: 6000, stock: 10),
    MedicineModel(name: 'tuseran', priceCentavos: 1400, stock: 36),
    MedicineModel(name: 'Tuseran', priceCentavos: 2200, stock: 0),
    MedicineModel(name: 'vicks', priceCentavos: 3600, stock: 23),
  ];

  @override
  List<MedicineModel> all() => _sorted(_items);

  @override
  List<MedicineModel> search(String query) {
    if (query.trim().isEmpty) return all();
    return _sorted(_items.where((item) => item.matches(query)));
  }

  /// Alphabetical ignoring case, then cheapest first. The second key is what
  /// keeps the repeated names in a sensible order, so `Amox` reads 4.00 then
  /// 45.00 rather than arbitrarily.
  static List<MedicineModel> _sorted(Iterable<MedicineModel> items) {
    final sorted = items.toList()
      ..sort((a, b) {
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return byName != 0
            ? byName
            : a.priceCentavos.compareTo(b.priceCentavos);
      });
    return List.unmodifiable(sorted);
  }
}
