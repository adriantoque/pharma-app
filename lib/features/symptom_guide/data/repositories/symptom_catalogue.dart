import '../models/symptom_entry.dart';

/// The symptom guide's content, transcribed by hand from the pharmacist.
///
/// ## Supplying the real text
///
/// The entries below are placeholders. Replace each block with the pharmacist's
/// wording in this shape, and the screens need no other change:
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
/// `isDraft: true` marks placeholder text. A screen showing a draft entry says
/// so in a banner, so scaffolding can never be mistaken for advice. Remove the
/// flag from an entry once its text has been reviewed.
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
    summary: '[Placeholder] A raised body temperature, often from an infection. '
        'Refer to the pharmacist if it lasts more than a few days or comes with '
        'a stiff neck, a rash, or confusion.',
    medicineNames: [
      'Biogesic 500mg Tablet (Paracetamol)',
      'Paracetamol 500mg (Generic Tablet)',
    ],
    referralNote: '[Placeholder] Refer to the pharmacist for fever in infants, '
        'or fever lasting more than three days.',
    isDraft: true,
  ),
  SymptomEntry(
    id: 'headache',
    name: 'Headache',
    aliases: ['sakit ng ulo', 'head pain', 'migraine', 'ulo'],
    summary: '[Placeholder] Pain in the head. Refer to the pharmacist if it is '
        'sudden and severe, follows a head injury, or comes with a fever and '
        'neck stiffness.',
    medicineNames: [
      'Biogesic 500mg Tablet (Paracetamol)',
      'Medicol Advance 200mg Softgel',
    ],
    isDraft: true,
  ),
  SymptomEntry(
    id: 'cough',
    name: 'Cough',
    aliases: ['ubo', 'coughing', 'dry cough', 'phlegm'],
    summary: '[Placeholder] A cough, often from a cold. Refer to the pharmacist '
        'if it lasts more than two weeks, brings up blood, or comes with '
        'breathing difficulty.',
    medicineNames: [
      'Solmux 500mg Capsule (Carbocisteine)',
      'Bioflu Tablet',
    ],
    isDraft: true,
  ),
  SymptomEntry(
    id: 'allergy',
    name: 'Allergy',
    aliases: ['allergies', 'sneezing', 'itching', 'allergic', 'hives'],
    summary: '[Placeholder] Sneezing, itching, or a runny nose from an allergen. '
        'Refer to the pharmacist at once for swelling of the face or throat or '
        'difficulty breathing.',
    medicineNames: [
      'Cetirizine 10mg (Generic Tablet)',
      'Virlix 10mg Tablet (Cetirizine)',
      'Allerkid 5mg/5mL Syrup 60mL',
    ],
    isDraft: true,
  ),
];
