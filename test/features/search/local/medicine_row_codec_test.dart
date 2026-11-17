// The row codec, without a database.
//
// Every test here constructs [MedicineRow] directly, which is why none of them
// need SQLite: the codec is a pure pair of functions plus the change-detection
// helpers, and the database only ever hands the codec a row it already built.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/search/data/local/app_database.dart';
import 'package:pharmaguide/features/search/data/local/medicine_row_codec.dart';
import 'package:pharmaguide/features/search/data/models/age_guidance.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';

MedicineModel _medicine({
  String? productId,
  String? usage,
  int? stock,
  List<String> aliases = const [],
  DateTime? expiry,
  AgeGuidance? guidance,
  String? packageType,
  int price = 900,
}) {
  return MedicineModel(
    name: 'Alaxan FR Capsule',
    productId: productId,
    packageType: packageType,
    usageIndication: usage,
    priceCentavos: price,
    stock: stock,
    aliases: aliases,
    genericKey: 'ibuprofen + paracetamol',
    expiryDate: expiry,
    requiresRx: false,
    category: 'Pain & Fever',
    dosageInfo: '1 capsule every 6 to 8 hours',
    cautions: 'Ages 12+',
    ageGroup: AgeGroup.adult,
    ageGuidance: guidance,
  );
}

void main() {
  group('rowFromMedicine / medicineFromRow', () {
    test('round-trips every field', () {
      final medicine = _medicine(
        productId: '28',
        usage: 'For body aches',
        stock: 20,
        aliases: const ['alaxan'],
        expiry: DateTime(2027, 3, 9),
        guidance: const AgeGuidance(
          kids: AgeSuitability.no,
          teens: AgeSuitability.yes,
          adults: AgeSuitability.yes,
          seniors: AgeSuitability.caution,
        ),
      );

      final roundTripped = medicineFromRow(rowFromMedicine(medicine));

      expect(roundTripped.name, medicine.name);
      expect(roundTripped.productId, '28');
      expect(roundTripped.priceCentavos, medicine.priceCentavos);
      expect(roundTripped.stock, 20);
      expect(roundTripped.aliases, ['alaxan']);
      expect(roundTripped.genericKey, medicine.genericKey);
      expect(roundTripped.expiryDate, medicine.expiryDate);
      expect(roundTripped.requiresRx, isFalse);
      expect(roundTripped.category, medicine.category);
      expect(roundTripped.dosageInfo, medicine.dosageInfo);
      expect(roundTripped.cautions, medicine.cautions);
      expect(roundTripped.ageGroup, AgeGroup.adult);
      expect(roundTripped.usageIndication, medicine.usageIndication);
      expect(roundTripped.ageGuidance, isNotNull);
      expect(roundTripped.ageGuidance!.kids, AgeSuitability.no);
      expect(roundTripped.ageGuidance!.seniors, AgeSuitability.caution);
    });

    test('keys the row on the model document id, not on a hash of the row', () {
      final row = rowFromMedicine(_medicine(productId: '28'));
      expect(row.id, _medicine(productId: '28').documentId);
    });

    test('keeps an uncounted line uncounted, not zero', () {
      final roundTripped = medicineFromRow(rowFromMedicine(_medicine()));
      expect(roundTripped.stock, isNull);
      expect(roundTripped.isStockUnknown, isTrue);
    });

    test('keeps an absent descriptive field absent', () {
      final roundTripped = medicineFromRow(rowFromMedicine(_medicine()));
      expect(roundTripped.usageIndication, isNull);
      expect(roundTripped.ageGuidance, isNull);
      expect(roundTripped.expiryDate, isNull);
    });

    test('drops an alias that is not a name', () {
      final row = rowFromMedicine(_medicine(aliases: ['alaxan']));
      // Written directly, the way a corrupted write or a hand edit would land.
      final corrupt = MedicineRow(
        id: row.id,
        name: row.name,
        productId: null,
        packageType: null,
        usageIndication: null,
        priceCentavos: row.priceCentavos,
        stock: null,
        aliases: '{"alaxan",28,}',
        genericKey: null,
        expiryDate: null,
        requiresRx: false,
        category: null,
        dosageInfo: null,
        cautions: null,
        ageGroup: 'both',
        ageGuidance: null,
        updatedAt: null,
      );
      expect(medicineFromRow(corrupt).aliases, const <String>[]);
    });
  });

  group('sameStoredMedicine', () {
    test('false when only the stock count changed', () {
      final stored = rowFromMedicine(_medicine(stock: 9));
      final mirrored = rowFromMedicine(_medicine(stock: 12));
      expect(
        sameStoredMedicine(medicineFromRow(stored), medicineFromRow(mirrored)),
        isFalse,
      );
    });

    test('false when only the expiry changed', () {
      final stored = rowFromMedicine(_medicine());
      final mirrored = rowFromMedicine(_medicine(expiry: DateTime(2027, 3, 9)));
      expect(
        sameStoredMedicine(medicineFromRow(stored), medicineFromRow(mirrored)),
        isFalse,
      );
    });

    test('true for the same line stored twice', () {
      final medicine = _medicine(
        productId: '28',
        usage: 'For body aches',
        stock: 9,
      );
      expect(
        sameStoredMedicine(medicineFromRow(rowFromMedicine(medicine)), medicine),
        isTrue,
      );
    });

    test('true when both sides have nothing', () {
      expect(sameStoredMedicine(null, null), isTrue);
    });

    test('false when one side has nothing', () {
      expect(
        sameStoredMedicine(null, _medicine(productId: '28')),
        isFalse,
      );
      expect(
        sameStoredMedicine(_medicine(productId: '28'), null),
        isFalse,
      );
    });

    test('is not fooled by identity-only equality', () {
      // MedicineModel == compares name and price only, so a stock change still
      // reads as "the same medicine". The fingerprint must not.
      final medicine = _medicine(productId: '28');
      final changed = medicine.copyWith(
        stock: 3,
        expiryDate: DateTime(2027, 1, 1),
      );
      expect(medicine, changed);
      expect(sameStoredMedicine(medicine, changed), isFalse);
    });
  });
}
