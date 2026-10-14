/// How to use one medicine, and what to warn the customer about.
///
/// Directions and cautions only. No numeric doses: a dose the app prints is a
/// dose nobody checked, and the counter already has the product label and a
/// pharmacist for that.
///
/// Keyed by the lowercased medicine name, the same way `MedicineInformation`
/// is, so a suggestion in `symptom_catalogue.dart` looks its directions up with
/// nothing more than the name it stored.
///
/// The text here is placeholder content awaiting pharmacist review. Every entry
/// carries [isDraft] so the screen can say so out loud.
class MedicineGuidance {
  const MedicineGuidance({
    required this.howToUse,
    required this.cautions,
    this.isDraft = false,
  });

  /// Plain-language directions: how it is taken, with what, and anything that
  /// changes how it works (e.g. "after food").
  final String howToUse;

  /// Warnings and red flags: who should not take it, and when to stop and ask
  /// the pharmacist.
  final String cautions;

  /// Whether this is placeholder text awaiting pharmacist review.
  final bool isDraft;

  /// Placeholder directions and cautions, keyed by lowercased medicine name.
  ///
  /// Replaced wholesale when the pharmacist supplies the real text. The names
  /// must match entries in the live price list; the catalogue-integrity test
  /// checks that a suggested medicine is one the counter can actually sell, but
  /// the directions below are the app's scaffold, not clinical advice.
  static const Map<String, MedicineGuidance> _byName = {
    'biogesic 500mg tablet (paracetamol)': MedicineGuidance(
      howToUse: '[Placeholder] Swallow with water. Can be taken with or without '
          'food. Replace with the pharmacist\'s wording.',
      cautions: '[Placeholder] Do not take with other paracetamol products. '
          'Ask the pharmacist if pregnant. Replace with the pharmacist\'s '
          'wording.',
      isDraft: true,
    ),
    'paracetamol 500mg (generic tablet)': MedicineGuidance(
      howToUse: '[Placeholder] Swallow with water. Can be taken with or without '
          'food. Replace with the pharmacist\'s wording.',
      cautions: '[Placeholder] Do not take with other paracetamol products. '
          'Replace with the pharmacist\'s wording.',
      isDraft: true,
    ),
    'medicol advance 200mg softgel': MedicineGuidance(
      howToUse: '[Placeholder] Swallow with water, preferably after food. '
          'Replace with the pharmacist\'s wording.',
      cautions: '[Placeholder] Can irritate the stomach. Ask the pharmacist '
          'before use with stomach ulcers or asthma. Replace with the '
          'pharmacist\'s wording.',
      isDraft: true,
    ),
    'cetirizine 10mg (generic tablet)': MedicineGuidance(
      howToUse: '[Placeholder] Swallow with water. Replace with the '
          'pharmacist\'s wording.',
      cautions: '[Placeholder] May cause drowsiness; avoid driving until you '
          'know how it affects you. Replace with the pharmacist\'s wording.',
      isDraft: true,
    ),
    'virlix 10mg tablet (cetirizine)': MedicineGuidance(
      howToUse: '[Placeholder] Swallow with water. Replace with the '
          'pharmacist\'s wording.',
      cautions: '[Placeholder] May cause drowsiness. Replace with the '
          'pharmacist\'s wording.',
      isDraft: true,
    ),
    'allerkid 5mg/5ml syrup 60ml': MedicineGuidance(
      howToUse: '[Placeholder] Measure with the supplied cup. Replace with the '
          'pharmacist\'s wording.',
      cautions: '[Placeholder] May cause drowsiness. Replace with the '
          'pharmacist\'s wording.',
      isDraft: true,
    ),
    'solmux 500mg capsule (carbocisteine)': MedicineGuidance(
      howToUse: '[Placeholder] Take as directed on the label. Replace with the '
          'pharmacist\'s wording.',
      cautions: '[Placeholder] Check the label for ingredients you may also be '
          'taking. Replace with the pharmacist\'s wording.',
      isDraft: true,
    ),
    'bioflu tablet': MedicineGuidance(
      howToUse: '[Placeholder] Take as directed on the label. Replace with the '
          'pharmacist\'s wording.',
      cautions: '[Placeholder] May cause drowsiness. Replace with the '
          'pharmacist\'s wording.',
      isDraft: true,
    ),
  };

  /// The guidance for [name], or null when none is recorded.
  static MedicineGuidance? forName(String name) =>
      _byName[name.trim().toLowerCase()];
}
