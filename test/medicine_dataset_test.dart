import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/search/data/repositories/bundled_medicine_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads the pharmacy workbook catalogue with unique product IDs',
    () async {
      final medicines = await BundledMedicineSource().load();
      final productIds = medicines
          .map((medicine) => medicine.productId)
          .toSet();

      expect(medicines, hasLength(100));
      expect(productIds, hasLength(100));
      expect(
        medicines.every((medicine) => medicine.packageType != null),
        isTrue,
      );
      expect(medicines.every((medicine) => medicine.stock != null), isTrue);
      expect(
        medicines.every(
          (medicine) =>
              medicine.usageIndication != null &&
              medicine.usageIndication!.isNotEmpty,
        ),
        isTrue,
      );
      expect(
        medicines
            .firstWhere((medicine) => medicine.productId == '1')
            .usageIndication,
        'For fever and mild to moderate pain relief',
      );
    },
  );
}
