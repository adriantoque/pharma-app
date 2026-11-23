import 'package:drift/drift.dart';

/// One price-list line, on disk.
///
/// A single table rather than a normalised catalogue with an aliases child
/// table. Search runs in Dart against the loaded list ([MedicineModel.matches]),
/// never in SQL, so an indexed alias table would buy nothing today and cost a
/// join on every read. The `aliases` and `ageGuidance` columns hold JSON
/// instead; the codec in `medicine_row_codec.dart` owns both directions.
@DataClassName('MedicineRow')
class MedicineRows extends Table {
  /// The line's identity: [MedicineModel.documentId], the FNV-1a hash the model
  /// derives from its product id (or name, package and price). Primary key, so
  /// a re-import of the same spreadsheet updates the row in place instead of
  /// duplicating it -- the same rule the Firestore collection follows.
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get productId => text().nullable()();

  TextColumn get packageType => text().nullable()();

  TextColumn get usageIndication => text().nullable()();

  /// Centavos, integer, for the same reason [MedicineModel.priceCentavos] is.
  IntColumn get priceCentavos => integer()();

  /// Units on the shelf, or null when nobody has counted them. Null is a real
  /// state here exactly as it is in the model: a count that failed to parse
  /// must read as uncounted, never as zero.
  IntColumn get stock => integer().nullable()();

  /// JSON list of alternative spellings.
  TextColumn get aliases => text().withDefault(const Constant('[]'))();

  TextColumn get genericKey => text().nullable()();

  /// The shelf expiry as `yyyy-MM-dd`, or null. Deliberately a string, matching
  /// how the Firestore documents and the offline overlay store it: a date with
  /// no time of day must not grow one in a different column type.
  TextColumn get expiryDate => text().nullable()();

  BoolColumn get requiresRx => boolean().withDefault(const Constant(false))();

  TextColumn get category => text().nullable()();

  TextColumn get dosageInfo => text().nullable()();

  TextColumn get cautions => text().nullable()();

  TextColumn get ageGroup => text().withDefault(const Constant('both'))();

  /// JSON object `{kids, teens, adults, seniors}`, or null when not recorded.
  TextColumn get ageGuidance => text().nullable()();

  /// Millis since epoch of the last write, for no behaviour -- kept so a future
  /// sync decision ("which row is newer") does not have to invent the column.
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
