import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/search/data/models/medicine_information.dart';

void main() {
  test('medicine information lookup ignores letter case and whitespace', () {
    final information = MedicineInformation.forName('  CETIRIZINE  ');

    expect(information?.type, 'Antihistamine');
    expect(information?.purpose, contains('relieve allergy symptoms'));
  });

  test('unverified catalogue names do not get guessed information', () {
    expect(MedicineInformation.forName('Alcohol'), isNull);
  });
}
