import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';

/// Covers the parts of [MedicineModel] that exist so a price list can be stored
/// in Firestore and read back: the document id, and the round trip.
void main() {
  const line = MedicineModel(
    name: 'CETERIZINE',
    priceCentavos: 300,
    stock: 12,
    aliases: ['cetirizine', 'ceterizinne'],
    genericKey: 'Cetirizine',
    expiryDate: null,
  );

  group('the document id', () {
    test('is the same for two equal lines', () {
      expect(line.documentId, line.copyWith().documentId);
    });

    test('is eight lowercase hex characters', () {
      // A Firestore id may not contain a slash, and the seeder builds a path
      // from it, so the shape is worth pinning rather than assuming.
      expect(line.documentId, matches(RegExp(r'^[0-9a-f]{8}$')));
    });

    test('differs when the price differs', () {
      // `Amox` is sold at both 4.00 and 45.00 and those are two products, so
      // they must not land on one document or one would overwrite the other.
      expect(
        const MedicineModel(name: 'Amox', priceCentavos: 400, stock: null)
            .documentId,
        isNot(
          const MedicineModel(name: 'Amox', priceCentavos: 4500, stock: null)
              .documentId,
        ),
      );
    });

    test('differs when the name differs', () {
      expect(
        const MedicineModel(name: 'Amox', priceCentavos: 400, stock: null)
            .documentId,
        isNot(
          const MedicineModel(name: 'amox', priceCentavos: 400, stock: null)
              .documentId,
        ),
      );
    });

    test('is unaffected by stock, aliases or expiry', () {
      // Those are state, not identity. A count typed at the counter has to land
      // on the same document the import created.
      expect(line.documentId, line.copyWith(stock: 0).documentId);
      expect(
        line.documentId,
        line.copyWith(aliases: const ['x']).documentId,
      );
      expect(
        line.documentId,
        line.copyWith(expiryDate: DateTime(2027, 3, 1)).documentId,
      );
    });

    test('does not change between runs', () {
      // Pinned on purpose. The id is an FNV-1a hash of the identity rather than
      // `hashCode`, which is only stable within a process; if this value ever
      // moves, every document is re-created and the stock counts are orphaned,
      // so a change here has to be a deliberate one.
      expect(line.documentId, '26daaa4e');
    });
  });

  group('Firestore round trip', () {
    test('keeps every field', () {
      final restored = MedicineModel.fromFirestore(line.toFirestore());

      expect(restored.name, 'CETERIZINE');
      expect(restored.priceCentavos, 300);
      expect(restored.stock, 12);
      expect(restored.aliases, ['cetirizine', 'ceterizinne']);
      expect(restored.genericKey, 'Cetirizine');
    });

    test('keeps an uncounted item uncounted', () {
      // The single most important case: null has to survive as null, or a
      // freshly imported catalogue comes back with a count of zero and every
      // product in it reads as out of stock.
      const uncounted = MedicineModel(name: 'Amox', priceCentavos: 400, stock: null);
      final restored = MedicineModel.fromFirestore(uncounted.toFirestore());

      expect(restored.stock, isNull);
      expect(restored.isStockUnknown, isTrue);
      expect(restored.isOutOfStock, isFalse);
    });

    test('keeps a zero count as out of stock', () {
      // Zero and null are different answers and must not be confused on the way
      // through storage: only one of them may block an order.
      const empty = MedicineModel(name: 'Amox', priceCentavos: 400, stock: 0);
      final restored = MedicineModel.fromFirestore(empty.toFirestore());

      expect(restored.stock, 0);
      expect(restored.isOutOfStock, isTrue);
      expect(restored.isStockUnknown, isFalse);
    });

    test('writes the expiry as a plain date, with no time of day', () {
      const dated = MedicineModel(
        name: 'Amox',
        priceCentavos: 400,
        stock: 1,
        expiryDate: null,
      );
      // A shelf expiry is a date; a Timestamp would invent a time of day that
      // nobody recorded.
      expect(
        MedicineModel.fromFirestore(
          dated.copyWith(expiryDate: DateTime(2027, 3, 9)).toFirestore(),
        ).expiryDate,
        DateTime(2027, 3, 9),
      );
    });

    test('reads an expiry back at midnight, not at the stored time', () {
      final restored = MedicineModel.fromFirestore({
        'name': 'Amox',
        'priceCentavos': 400,
        'stock': null,
        'expiryDate': '2027-03-09T14:30:00.000Z',
      });

      expect(restored.expiryDate, isNotNull);
      expect(restored.expiryDate!.hour, 0);
    });

    test('reads an unpadded date', () {
      expect(
        MedicineModel.fromFirestore({
          'name': 'Amox',
          'priceCentavos': 400,
          'expiryDate': '2027-3-9',
        }).expiryDate,
        DateTime(2027, 3, 9),
      );
    });

    test('reads a Timestamp expiry, as written by hand in the console', () {
      expect(
        MedicineModel.fromFirestore({
          'name': 'Amox',
          'priceCentavos': 400,
          'expiryDate': DateTime(2027, 3, 9, 14, 30),
        }).expiryDate,
        DateTime(2027, 3, 9),
      );
    });

    test('reads a number stored as a double', () {
      expect(
        MedicineModel.fromFirestore({
          'name': 'Amox',
          'priceCentavos': 400.0,
          'stock': 7.0,
        }).stock,
        7,
      );
    });

    test('reads a missing or unreadable field as uncounted, not as zero', () {
      // The app cannot tell an uncounted item from one whose field it failed to
      // parse, and both have to read as uncounted: a wrong zero would block the
      // sale of something that is on the shelf.
      expect(
        MedicineModel.fromFirestore({'name': 'Amox', 'priceCentavos': 400})
            .stock,
        isNull,
      );
      expect(
        MedicineModel.fromFirestore({
          'name': 'Amox',
          'priceCentavos': 400,
          'stock': 'not a number',
        }).stock,
        isNull,
      );
    });

    test('reads an unreadable expiry as no expiry', () {
      expect(
        MedicineModel.fromFirestore({
          'name': 'Amox',
          'priceCentavos': 400,
          'expiryDate': 'soon',
        }).expiryDate,
        isNull,
      );
      expect(
        MedicineModel.fromFirestore({
          'name': 'Amox',
          'priceCentavos': 400,
          'expiryDate': '2027-13-45',
        }).expiryDate,
        isNull,
      );
    });

    test('drops blank aliases rather than indexing an empty string', () {
      expect(
        MedicineModel.fromFirestore({
          'name': 'Amox',
          'priceCentavos': 400,
          'aliases': ['amoxicilin', '', 'amoxcillin'],
        }).aliases,
        ['amoxicilin', 'amoxcillin'],
      );
    });

    test('survives a document missing everything', () {
      final restored = MedicineModel.fromFirestore(const {});

      expect(restored.name, isEmpty);
      expect(restored.stock, isNull);
      expect(restored.aliases, isEmpty);
    });

    test('a restored line has the same identity and id', () {
      final restored = MedicineModel.fromFirestore(line.toFirestore());

      expect(restored, line);
      expect(restored.documentId, line.documentId);
    });
  });

  group('copyWith', () {
    test('replaces only what it is given', () {
      final updated = line.copyWith(stock: 0);

      expect(updated.stock, 0);
      expect(updated.name, line.name);
      expect(updated.aliases, line.aliases);
    });

    test('leaves a field alone when the argument is not passed', () {
      final updated = line.copyWith(name: 'Cetirizine');

      expect(updated.stock, 12);
      expect(updated.genericKey, 'Cetirizine');
      expect(updated.expiryDate, isNull);
    });

    test('clears a count when null is passed', () {
      // The stock sheet's "Not counted" control resolves to a null stock, and
      // this is the line it goes through on the way to the optimistic update. A
      // null that quietly meant "keep the old value" would put the count back
      // after a member of staff had deliberately cleared it.
      expect(line.copyWith(stock: null).stock, isNull);
      expect(line.copyWith(stock: 12).copyWith(stock: null).stock, isNull);
    });

    test('clears an expiry when null is passed', () {
      final dated = line.copyWith(expiryDate: DateTime(2026, 3));

      expect(dated.expiryDate, DateTime(2026, 3));
      expect(dated.copyWith(expiryDate: null).expiryDate, isNull);
    });

    test('clears a generic link when null is passed', () {
      expect(line.copyWith(genericKey: null).genericKey, isNull);
    });

    test('distinguishes not counting from being out of stock', () {
      // The two states a pharmacy must never confuse: one is a missing count,
      // the other is a counted empty shelf, and only the second blocks an order.
      expect(line.copyWith(stock: null).stockState, StockState.unknown);
      expect(line.copyWith(stock: 0).stockState, StockState.outOfStock);
    });

    test('keeps the identity, so the update lands on the same document', () {
      expect(line.copyWith(stock: 99).documentId, line.documentId);
      expect(line.copyWith(stock: null).documentId, line.documentId);
    });
  });
}
