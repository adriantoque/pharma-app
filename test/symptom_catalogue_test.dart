import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/search/data/repositories/bundled_medicine_source.dart';
import 'package:pharmaguide/features/symptom_guide/data/repositories/symptom_catalogue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every symptom id is unique', () {
    final ids = symptomCatalogue.map((entry) => entry.id).toList();

    expect(ids.toSet(), hasLength(ids.length));
  });

  test('every suggested medicine resolves in the live price list', () async {
    final stocked = (await BundledMedicineSource().load())
        .map((medicine) => medicine.name.trim().toLowerCase())
        .toSet();

    for (final entry in symptomCatalogue) {
      for (final name in entry.medicineNames) {
        expect(
          stocked,
          contains(name.trim().toLowerCase()),
          reason: '${entry.id} suggests "$name", which is not in the dataset',
        );
      }
    }
  });
}
