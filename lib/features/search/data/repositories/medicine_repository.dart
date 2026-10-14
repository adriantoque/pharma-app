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
///
/// Transcribed from the pharmacy's imported workbook, and kept in step with the
/// bundled catalogue the Medicine tab reads: the same 40 product names and
/// package prices, carrying their [MedicineModel.productId] and
/// [MedicineModel.packageType] so a medicine scanned here names the same product
/// the catalogue shows. A handful of names keep their blister and box packages
/// so repeated product names at different prices stay distinct.
///
/// The `stock:` values are PLACEHOLDERS, not real counts -- the source data was
/// a price list with no quantities on it. They are spread on purpose so every
/// stock state is reviewable on screen: five items are out of stock, five more
/// are at or below [MedicineModel.lowStockThreshold], and Paracetamol sits above
/// the order's own 99-per-item ceiling so that ceiling stays the binding limit.
/// Replace them with the real numbers in one pass; nothing else in the app
/// hard-codes a level.
class StaticMedicineRepository implements MedicineRepository {
  const StaticMedicineRepository();

  static final List<MedicineModel> _items = [
    // Paracetamol (generic) keeps all three packages.
    MedicineModel(
      productId: '1',
      name: 'Paracetamol 500mg (Generic Tablet)',
      packageType: 'Piece (Dosage)',
      usageIndication: 'For fever and mild to moderate pain relief',
      priceCentavos: 200,
      stock: 120,
    ),
    MedicineModel(
      productId: '2',
      name: 'Paracetamol 500mg (Generic Tablet)',
      packageType: 'Blister Pack (10s)',
      usageIndication: 'For fever and mild to moderate pain relief',
      priceCentavos: 1800,
      stock: 20,
    ),
    MedicineModel(
      productId: '3',
      name: 'Paracetamol 500mg (Generic Tablet)',
      packageType: 'Box (100s)',
      usageIndication: 'For fever and mild to moderate pain relief',
      priceCentavos: 15000,
      stock: 20,
    ),
    // Biogesic keeps all three packages.
    MedicineModel(
      productId: '4',
      name: 'Biogesic 500mg Tablet (Paracetamol)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 500,
      stock: 20,
      genericKey: 'Paracetamol',
    ),
    MedicineModel(
      productId: '5',
      name: 'Biogesic 500mg Tablet (Paracetamol)',
      packageType: 'Blister Pack (10s)',
      priceCentavos: 4800,
      stock: 20,
      genericKey: 'Paracetamol',
    ),
    MedicineModel(
      productId: '6',
      name: 'Biogesic 500mg Tablet (Paracetamol)',
      packageType: 'Box (500s)',
      priceCentavos: 235000,
      stock: 20,
      genericKey: 'Paracetamol',
    ),
    // Amoxicillin (generic) keeps all three packages.
    MedicineModel(
      productId: '7',
      name: 'Amoxicillin 500mg (Generic Capsule)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 400,
      stock: 20,
    ),
    MedicineModel(
      productId: '8',
      name: 'Amoxicillin 500mg (Generic Capsule)',
      packageType: 'Blister Pack (10s)',
      priceCentavos: 3800,
      stock: 20,
    ),
    MedicineModel(
      productId: '9',
      name: 'Amoxicillin 500mg (Generic Capsule)',
      packageType: 'Box (100s)',
      priceCentavos: 35000,
      stock: 20,
    ),
    MedicineModel(
      productId: '10',
      name: 'Amoxil 500mg Capsule (Amoxicillin)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 1800,
      stock: 20,
      genericKey: 'Amoxicillin',
    ),
    MedicineModel(
      productId: '13',
      name: 'Mefenamic Acid 500mg (Generic Capsule)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 300,
      stock: 0,
    ),
    MedicineModel(
      productId: '16',
      name: 'Dolfenal 500mg Tablet (Mefenamic Acid)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 2800,
      stock: 5,
      genericKey: 'Mefenamic Acid',
    ),
    MedicineModel(
      productId: '19',
      name: 'Bioflu Tablet',
      packageType: 'Piece (Dosage)',
      priceCentavos: 800,
      stock: 20,
    ),
    MedicineModel(
      productId: '22',
      name: 'Decolgen Forte Tablet',
      packageType: 'Piece (Dosage)',
      priceCentavos: 700,
      stock: 3,
    ),
    MedicineModel(
      productId: '25',
      name: 'Neozep Zapp Caplet',
      packageType: 'Piece (Dosage)',
      priceCentavos: 700,
      stock: 20,
    ),
    MedicineModel(
      productId: '28',
      name: 'Alaxan FR Capsule',
      packageType: 'Piece (Dosage)',
      priceCentavos: 900,
      stock: 2,
    ),
    MedicineModel(
      productId: '31',
      name: 'Ibuprofen 200mg (Generic Tablet)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 200,
      stock: 20,
    ),
    MedicineModel(
      productId: '34',
      name: 'Medicol Advance 200mg Softgel',
      packageType: 'Piece (Dosage)',
      priceCentavos: 800,
      stock: 20,
    ),
    // Diatabs keeps all three packages.
    MedicineModel(
      productId: '37',
      name: 'Diatabs 2mg Capsule (Loperamide)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 800,
      stock: 20,
      genericKey: 'Loperamide',
    ),
    MedicineModel(
      productId: '38',
      name: 'Diatabs 2mg Capsule (Loperamide)',
      packageType: 'Blister Pack (10s)',
      priceCentavos: 7800,
      stock: 20,
      genericKey: 'Loperamide',
    ),
    MedicineModel(
      productId: '39',
      name: 'Diatabs 2mg Capsule (Loperamide)',
      packageType: 'Box (100s)',
      priceCentavos: 75000,
      stock: 20,
      genericKey: 'Loperamide',
    ),
    MedicineModel(
      productId: '40',
      name: 'Loperamide 2mg (Generic Capsule)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 300,
      stock: 20,
    ),
    MedicineModel(
      productId: '43',
      name: 'Kremil-S Tablet',
      packageType: 'Piece (Dosage)',
      priceCentavos: 800,
      stock: 20,
    ),
    MedicineModel(
      productId: '46',
      name: 'Omeprazole 20mg (Generic Capsule)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 500,
      stock: 20,
    ),
    MedicineModel(
      productId: '49',
      name: 'Losec 20mg Capsule (Omeprazole)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 7000,
      stock: 20,
      genericKey: 'Omeprazole',
    ),
    // Cetirizine (generic) keeps all three packages.
    MedicineModel(
      productId: '52',
      name: 'Cetirizine 10mg (Generic Tablet)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 300,
      stock: 20,
    ),
    MedicineModel(
      productId: '53',
      name: 'Cetirizine 10mg (Generic Tablet)',
      packageType: 'Blister Pack (10s)',
      priceCentavos: 2800,
      stock: 20,
    ),
    MedicineModel(
      productId: '54',
      name: 'Cetirizine 10mg (Generic Tablet)',
      packageType: 'Box (100s)',
      priceCentavos: 25000,
      stock: 20,
    ),
    MedicineModel(
      productId: '55',
      name: 'Virlix 10mg Tablet (Cetirizine)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 3500,
      stock: 20,
      genericKey: 'Cetirizine',
    ),
    MedicineModel(
      productId: '58',
      name: 'Allerkid 5mg/5mL Syrup 60mL',
      packageType: 'Bottle (60mL)',
      priceCentavos: 16500,
      stock: 20,
    ),
    MedicineModel(
      productId: '60',
      name: 'Allerkid 2.5mg/mL Oral Drops 10mL',
      packageType: 'Bottle (10mL)',
      priceCentavos: 14000,
      stock: 0,
    ),
    MedicineModel(
      productId: '62',
      name: 'Ascorbic Acid 500mg (Generic Tablet)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 200,
      stock: 20,
    ),
    MedicineModel(
      productId: '65',
      name: 'Fern-C 500mg Capsule (Sodium Ascorbate)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 700,
      stock: 20,
      genericKey: 'Sodium Ascorbate',
    ),
    MedicineModel(
      productId: '68',
      name: 'Enervon-C Tablet',
      packageType: 'Piece (Dosage)',
      priceCentavos: 700,
      stock: 20,
    ),
    MedicineModel(
      productId: '71',
      name: 'Revicon Forte Tablet',
      packageType: 'Piece (Dosage)',
      priceCentavos: 800,
      stock: 0,
    ),
    MedicineModel(
      productId: '74',
      name: 'Amlodipine 5mg (Generic Tablet)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 200,
      stock: 20,
    ),
    MedicineModel(
      productId: '77',
      name: 'Norvasc 5mg Tablet (Amlodipine)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 2400,
      stock: 4,
      genericKey: 'Amlodipine',
    ),
    MedicineModel(
      productId: '80',
      name: 'Losartan 50mg (Generic Tablet)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 300,
      stock: 20,
    ),
    MedicineModel(
      productId: '83',
      name: 'Cozaar 50mg Tablet (Losartan)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 3200,
      stock: 1,
      genericKey: 'Losartan',
    ),
    MedicineModel(
      productId: '86',
      name: 'Metformin 500mg (Generic Tablet)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 200,
      stock: 20,
    ),
    MedicineModel(
      productId: '89',
      name: 'Glucophage 500mg Tablet (Metformin)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 1400,
      stock: 20,
      genericKey: 'Metformin',
    ),
    MedicineModel(
      productId: '92',
      name: 'Green Cross Ethyl Alcohol 70% 250mL',
      packageType: 'Bottle (250mL)',
      priceCentavos: 4800,
      stock: 20,
    ),
    MedicineModel(
      productId: '93',
      name: 'Green Cross Ethyl Alcohol 70% 500mL',
      packageType: 'Bottle (500mL)',
      priceCentavos: 8800,
      stock: 20,
    ),
    MedicineModel(
      productId: '94',
      name: 'Casino Isopropyl Alcohol 70% 250mL',
      packageType: 'Bottle (250mL)',
      priceCentavos: 4500,
      stock: 20,
    ),
    MedicineModel(
      productId: '95',
      name: 'Casino Isopropyl Alcohol 70% 500mL',
      packageType: 'Bottle (500mL)',
      priceCentavos: 8200,
      stock: 0,
    ),
    MedicineModel(
      productId: '96',
      name: 'Betadine Antiseptic Solution 10% 15mL',
      packageType: 'Bottle (15mL)',
      priceCentavos: 6500,
      stock: 20,
    ),
    MedicineModel(
      productId: '97',
      name: 'Efficascent Oil Regular 100mL',
      packageType: 'Bottle (100mL)',
      priceCentavos: 5800,
      stock: 20,
    ),
    MedicineModel(
      productId: '98',
      name: 'White Flower Embrocation 5mL',
      packageType: 'Bottle (5mL)',
      priceCentavos: 7500,
      stock: 20,
    ),
    MedicineModel(
      productId: '99',
      name: 'Vicks Vaporub Ointment 25g',
      packageType: 'Jar (25g)',
      priceCentavos: 11000,
      stock: 0,
    ),
    MedicineModel(
      productId: '100',
      name: 'Solmux 500mg Capsule (Carbocisteine)',
      packageType: 'Piece (Dosage)',
      priceCentavos: 1200,
      stock: 20,
      genericKey: 'Carbocisteine',
    ),
  ];

  @override
  List<MedicineModel> all() => _sorted(_items);

  @override
  List<MedicineModel> search(String query) {
    if (query.trim().isEmpty) return all();
    return _sorted(_items.where((item) => item.matches(query)));
  }

  /// The list screen's order, using the model's shared comparator so the static
  /// list cannot drift from the sorted order the store and provider produce.
  static List<MedicineModel> _sorted(Iterable<MedicineModel> items) {
    final sorted = items.toList()
      ..sort(MedicineModel.compareByNameThenPrice);
    return List.unmodifiable(sorted);
  }
}
