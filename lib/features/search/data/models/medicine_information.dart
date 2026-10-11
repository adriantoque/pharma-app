import 'medicine_model.dart';

/// General, non-diagnostic information for catalogue items with a clear generic
/// identity. Brand or shorthand names without a verified identity are not guessed.
class MedicineInformation {
  const MedicineInformation({
    required this.type,
    required this.purpose,
    this.importantNote,
  });

  final String type;
  final String purpose;
  final String? importantNote;

  static const MedicineInformation unavailable = MedicineInformation(
    type: 'Information not available',
    purpose: 'The product type and purpose have not been confirmed for this catalogue entry.',
  );

  static const Map<String, MedicineInformation> _byCatalogueName = {
    'ascorbic tablet': MedicineInformation(
      type: 'Vitamin C supplement',
      purpose: 'Provides vitamin C and may be used to prevent or treat vitamin C deficiency.',
    ),
    'cetirizine': MedicineInformation(
      type: 'Antihistamine',
      purpose: 'Commonly used to relieve allergy symptoms such as sneezing, a runny nose, and itchy or watery eyes.',
    ),
    'cetirizine syrup': MedicineInformation(
      type: 'Antihistamine',
      purpose: 'Commonly used to relieve allergy symptoms such as sneezing, a runny nose, and itchy or watery eyes.',
    ),
    'cetirizine tab': MedicineInformation(
      type: 'Antihistamine',
      purpose: 'Commonly used to relieve allergy symptoms such as sneezing, a runny nose, and itchy or watery eyes.',
    ),
    'cinnarizine': MedicineInformation(
      type: 'Antihistamine',
      purpose: 'May be used for motion sickness or vertigo; follow the product label or a clinician’s advice.',
    ),
    'losartan': MedicineInformation(
      type: 'Angiotensin II receptor blocker (ARB)',
      purpose: 'Used to treat high blood pressure and certain heart or kidney conditions when prescribed.',
    ),
    'naproxen': MedicineInformation(
      type: 'Nonsteroidal anti-inflammatory drug (NSAID)',
      purpose: 'Used for temporary relief of pain and inflammation. Ask a pharmacist or clinician whether it is appropriate for you.',
    ),
    'paracetamol 125': MedicineInformation(
      type: 'Pain reliever and fever reducer',
      purpose: 'Paracetamol is used for temporary relief of pain and fever. The catalogue name does not confirm the product strength or form.',
    ),
    'salbutamol 4mg': MedicineInformation(
      type: 'Bronchodilator',
      purpose: 'Salbutamol is used to relieve wheezing and airway narrowing. Follow the prescribed instructions for this product.',
    ),
    'tramadol': MedicineInformation(
      type: 'Prescription opioid pain medicine',
      purpose: 'Used for certain types of moderate to severe pain when prescribed by a clinician.',
      importantNote: 'Can cause dependence and serious side effects. Use only as prescribed and ask a pharmacist or clinician about risks.',
    ),
  };

  factory MedicineInformation.forMedicine(MedicineModel medicine) =>
      _byCatalogueName[medicine.name.trim().toLowerCase()] ?? unavailable;
}
