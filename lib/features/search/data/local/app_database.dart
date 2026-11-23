import 'package:drift/drift.dart';

import 'medicine_rows.dart';
import 'open_database.dart';

part 'app_database.g.dart';

/// The local medicine cache: the durable mirror of the Firestore price list.
///
/// One instance per app, provided above the router in `main.dart` the same way
/// the `FirebaseFirestore` handle is. It is never closed at runtime -- stores
/// built over it come and go with sign-in, and closing the database under one
/// of them would break the next.
///
/// Firestore stays the source of truth (Option A). This database exists so the
/// catalogue and its unsent edits survive what the Firestore disk cache does
/// not: an app killed mid-queue, and the native cache being evicted under its
/// LRU budget.
@DriftDatabase(tables: [MedicineRows])
class AppDatabase extends _$AppDatabase {
  /// Opens the platform database. Lazily: no I/O happens until the first query.
  AppDatabase() : super(openAppDatabase());

  /// A database over an executor handed in, for tests (an in-memory database).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// Every row, one read.
  Future<List<MedicineRow>> allMedicines() => select(medicineRows).get();

  /// Every row, live: re-emits whenever the table changes.
  Stream<List<MedicineRow>> watchMedicines() => select(medicineRows).watch();

  /// Writes a full row, replacing any row with the same id.
  Future<void> writeMedicine(MedicineRow row) =>
      into(medicineRows).insertOnConflictUpdate(row);

  /// Writes many rows in one transaction, for seeding and mirroring.
  Future<void> writeMedicines(List<MedicineRow> rows) async {
    if (rows.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(medicineRows, rows);
    });
  }

  /// Records a stock count without touching the rest of the row.
  ///
  /// A partial update, not a full-row replace, for the same reason
  /// `FirestoreMedicineStore.setStock` merges one field: a mirror write or a
  /// concurrent expiry edit must not be clobbered by a stale copy of the row.
  Future<void> updateStock(String id, int? stock) {
    return (update(medicineRows)..where((t) => t.id.equals(id))).write(
      MedicineRowsCompanion(stock: Value(stock)),
    );
  }

  /// Records an expiry date without touching the rest of the row.
  Future<void> updateExpiry(String id, String? expiryDate) {
    return (update(medicineRows)..where((t) => t.id.equals(id))).write(
      MedicineRowsCompanion(expiryDate: Value(expiryDate)),
    );
  }

  /// One row by id, or null.
  Future<MedicineRow?> findMedicine(String id) {
    return (select(medicineRows)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Removes a row, for rollback when the server refuses a write that was
  /// already painted optimistically into the cache.
  Future<void> deleteMedicine(String id) {
    return (delete(medicineRows)..where((t) => t.id.equals(id))).go();
  }
}
