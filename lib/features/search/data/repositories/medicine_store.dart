import '../models/medicine_model.dart';

/// A live, writable price list.
///
/// Split from [MedicineRepository] on purpose. The read interface is a plain
/// list, which is all the prescription matcher and most widget tests need, and
/// they can keep using a static implementation of it forever. Everything that
/// needs a subscription or a write -- stock counts, expiry dates, seeding --
/// lives here, so a test that only reads the catalogue is never made to pretend
/// it has a database.
abstract interface class MedicineStore {
  /// The whole price list, live.
  ///
  /// Emits again on any change, so a count typed on the inventory screen reaches
  /// the search list without either screen knowing about the other. The first
  /// emission is the current contents, not a delta.
  Stream<List<MedicineModel>> watchAll();

  /// Records how many units are on the shelf.
  ///
  /// A null [stock] clears the count back to "Not counted", which is the one
  /// value that cannot be reached by typing a number and so needs a call of its
  /// own. It is not the same as passing zero, and a screen that cannot tell them
  /// apart will eventually mark a stocked item as unavailable.
  Future<void> setStock(MedicineModel medicine, int? stock);

  /// Records when this line expires, or clears the date with a null.
  Future<void> setExpiry(MedicineModel medicine, DateTime? expiry);

  /// Creates or replaces a price-list line.
  ///
  /// Keyed on [MedicineModel.documentId], so importing the same spreadsheet
  /// twice updates the existing documents and leaves the stock counts in place.
  Future<void> upsert(MedicineModel medicine);

  /// Writes many lines, for seeding an import.
  ///
  /// Batched rather than written one at a time because a full import is several
  /// hundred documents, and one round trip each would take long enough that
  /// seeding has to be watched from the console.
  Future<void> upsertAll(Iterable<MedicineModel> medicines);
}
