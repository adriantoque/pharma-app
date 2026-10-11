class MedicineInformation {
  const MedicineInformation({required this.type, required this.purpose});

  final String type;
  final String purpose;

  static const Map<String, MedicineInformation> _byName = {
    'amox': MedicineInformation(
      type: 'Antibiotic',
      purpose: 'Amoxicillin is used for certain bacterial infections. It does not treat viral illnesses.',
    ),
    'amox 250 cap': MedicineInformation(
      type: 'Antibiotic',
      purpose: 'Amoxicillin is used for certain bacterial infections. It does not treat viral illnesses.',
    ),
    'amox 500mg': MedicineInformation(
      type: 'Antibiotic',
      purpose: 'Amoxicillin is used for certain bacterial infections. It does not treat viral illnesses.',
    ),
    'ascorbic tablet': MedicineInformation(
      type: 'Vitamin supplement',
      purpose: 'Provides vitamin C.',
    ),
    'biogesic': MedicineInformation(
      type: 'Pain reliever and fever reducer',
      purpose: 'Paracetamol is used to relieve mild pain and reduce fever.',
    ),
    'cetirizine': MedicineInformation(
      type: 'Antihistamine',
      purpose: 'Used to relieve allergy symptoms such as sneezing and itching.',
    ),
    'cetirizine syrup': MedicineInformation(
      type: 'Antihistamine',
      purpose: 'Used to relieve allergy symptoms such as sneezing and itching.',
    ),
    'cetirizine tab': MedicineInformation(
      type: 'Antihistamine',
      purpose: 'Used to relieve allergy symptoms such as sneezing and itching.',
    ),
    'cloxacillin': MedicineInformation(
      type: 'Antibiotic',
      purpose: 'Used for certain bacterial infections when prescribed by a healthcare professional.',
    ),
    'diatabs': MedicineInformation(
      type: 'Anti-diarrheal',
      purpose: 'Used for symptomatic relief of diarrhea.',
    ),
    'enervon': MedicineInformation(
      type: 'Vitamin supplement',
      purpose:
          'Provides vitamins; check the package for its specific ingredients.',
    ),
    'erceflora': MedicineInformation(
      type: 'Probiotic',
      purpose: 'Provides probiotic microorganisms to support gut flora.',
    ),
    'flanax': MedicineInformation(
      type: 'Pain reliever and anti-inflammatory',
      purpose: 'Naproxen is used to relieve pain and inflammation.',
    ),
    'losartan': MedicineInformation(
      type: 'Blood pressure medicine',
      purpose: 'Used to treat high blood pressure.',
    ),
    'mefenamic': MedicineInformation(
      type: 'Pain reliever and anti-inflammatory',
      purpose: 'Mefenamic acid is used to relieve pain.',
    ),
    'naproxen': MedicineInformation(
      type: 'Pain reliever and anti-inflammatory',
      purpose: 'Used to relieve pain and inflammation.',
    ),
    'paracetamol 125': MedicineInformation(
      type: 'Pain reliever and fever reducer',
      purpose: 'Paracetamol is used to relieve mild pain and reduce fever.',
    ),
    'salbutamol 4mg': MedicineInformation(
      type: 'Bronchodilator',
      purpose: 'Used to relieve wheezing and shortness of breath.',
    ),
    'tempra 1-5': MedicineInformation(
      type: 'Pain reliever and fever reducer',
      purpose: 'Paracetamol is used to relieve mild pain and reduce fever.',
    ),
    'tramadol': MedicineInformation(
      type: 'Prescription pain reliever',
      purpose: 'Used for pain when prescribed. It can cause serious side effects and dependence.',
    ),
  };

  static MedicineInformation? forName(String name) =>
      _byName[name.trim().toLowerCase()];
}
