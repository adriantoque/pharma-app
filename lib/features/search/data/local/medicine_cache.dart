import '../repositories/medicine_store.dart';
import '../models/medicine_model.dart';

/// A price list that lives on this device and can be read in one shot.
///
/// [DriftMedicineStore] is the implementation; the interface exists so
/// [SyncedMedicineStore] can be tested against a cache that is a plain list
/// rather than a SQLite database. Everything here is a superset of
/// [MedicineStore]: the mirror needs to read the current rows to notice what a
/// server snapshot would actually change, and needs to put a rolled-back row
/// back exactly as it was after a refused write.
abstract interface class MedicineCache implements MedicineStore {
  /// The whole price list as it is stored right now, one read.
  ///
  /// Unlike [MedicineStore.watchAll] this does not subscribe: the mirror calls
  /// it once per server snapshot, and a live subscription per snapshot would
  /// multiply listeners for no information.
  Future<List<MedicineModel>> loadAll();

  /// One line by [MedicineModel.documentId], or null when it is not stored.
  ///
  /// Taken before a write so a refusal can be rolled back to exactly what was
  /// there, including "nothing".
  Future<MedicineModel?> findById(String documentId);

  /// Deletes one line, for rolling a write back when nothing was stored before.
  Future<void> deleteById(String documentId);
}
