import '../models/symptom_entry.dart';

/// The symptom guide's content, transcribed by hand from the pharmacist.
///
/// ## Supplying the text
///
/// Each entry is written in this shape, and the screens need no other change:
///
/// ```
/// Symptom: Fever
/// Aliases: temperature, lagnat, high temp
/// Summary: <1-2 sentences; include when to refer to the pharmacist>
/// Medicines:
///   - Biogesic 500mg Tablet (Paracetamol)
///       How to use: <directions, no numeric dose>
///       Cautions: <warnings / red flags>
///   - Paracetamol 500mg (Generic Tablet)
///       How to use: ...
///       Cautions: ...
/// Symptom: Headache
/// ...
/// ```
///
/// A symptom that should be handed to the pharmacist rather than treated at the
/// counter carries `referralNote` instead of (or as well as) a medicine list:
///
/// ```
/// Symptom: Chest pain
/// Aliases: chest tightness, heart pain
/// Summary: <when to refer>
/// Refer only: <the note the screen shows>
/// ```
///
/// `isDraft: true` marks text the pharmacist has not reviewed yet, so an entry
/// still being drafted can be told apart from one that is approved. It defaults
/// to false.
///
/// The `Medicines:` list is the pharmacist's *picks* and leads the detail
/// screen, but it is not the whole list: anything in the live price list whose
/// usage indication names the symptom (or one of its aliases) is offered behind
/// it. So an entry stays correct as the counter's stock changes without every
/// new product being added here by hand.
///
/// ## Rules the integrity test enforces
///
/// - every [SymptomEntry.id] is unique;
/// - every name in [SymptomEntry.medicineNames] resolves to a medicine in
///   `assets/data/medicines_seed.json`, so the guide cannot suggest something
///   the counter does not sell.
const List<SymptomEntry> symptomCatalogue = [
  SymptomEntry(
    id: 'fever',
    name: 'Fever',
    aliases: ['lagnat', 'temperature', 'high temp', 'feverish', 'mainit'],
    summary: 'A raised body temperature, often from an infection. '
        'Refer to the pharmacist if it lasts more than a few days or comes with '
        'a stiff neck, a rash, or confusion.',
    medicineNames: [
      'Biogesic 500mg Tablet (Paracetamol)',
      'Paracetamol 500mg (Generic Tablet)',
    ],
    referralNote: 'Refer to the pharmacist for fever in infants, '
        'or fever lasting more than three days.',
  ),
  SymptomEntry(
    id: 'headache',
    name: 'Headache',
    aliases: ['sakit ng ulo', 'head pain', 'migraine', 'ulo'],
    summary: 'Pain in the head. Refer to the pharmacist if it is '
        'sudden and severe, follows a head injury, or comes with a fever and '
        'neck stiffness.',
    medicineNames: [
      'Biogesic 500mg Tablet (Paracetamol)',
      'Medicol Advance 200mg Softgel',
    ],
  ),
  SymptomEntry(
    id: 'cough',
    name: 'Cough',
    aliases: ['ubo', 'coughing', 'dry cough', 'phlegm'],
    summary: 'A cough, often from a cold. Refer to the pharmacist '
        'if it lasts more than two weeks, brings up blood, or comes with '
        'breathing difficulty.',
    medicineNames: [
      'Solmux 500mg Capsule (Carbocisteine)',
      'Bioflu Tablet',
    ],
  ),
  SymptomEntry(
    id: 'allergy',
    name: 'Allergy',
    aliases: ['allergies', 'sneezing', 'itching', 'allergic', 'hives'],
    summary: 'Sneezing, itching, or a runny nose from an allergen. '
        'Refer to the pharmacist at once for swelling of the face or throat or '
        'difficulty breathing.',
    medicineNames: [
      'Cetirizine 10mg (Generic Tablet)',
      'Virlix 10mg Tablet (Cetirizine)',
      'Allerkid 5mg/5mL Syrup 60mL',
    ],
  ),
];
