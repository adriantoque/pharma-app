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
/// The text here is supplied and reviewed by the pharmacist. An entry carries
/// [isDraft] only while its text is still awaiting that review.
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

  /// Whether this text is still awaiting pharmacist review. Defaults to false.
  final bool isDraft;

  /// Directions and cautions, keyed by lowercased medicine name.
  ///
  /// The names must match entries in the live price list, so a suggestion in
  /// `symptom_catalogue.dart` resolves here with nothing more than the name it
  /// stored. A medicine with no entry falls back to an "ask the pharmacist" line
  /// rather than borrowing another medicine's text.
  static const Map<String, MedicineGuidance> _byName = {
    'biogesic 500mg tablet (paracetamol)': MedicineGuidance(
      howToUse: 'Swallow with water. Can be taken with or without food.',
      cautions: 'Do not take with other paracetamol products. Ask the '
          'pharmacist if pregnant.',
    ),
    'paracetamol 500mg (generic tablet)': MedicineGuidance(
      howToUse: 'Swallow with water. Can be taken with or without food.',
      cautions: 'Do not take with other paracetamol products.',
    ),
    'medicol advance 200mg softgel': MedicineGuidance(
      howToUse: 'Swallow with water, preferably after food.',
      cautions: 'Can irritate the stomach. Ask the pharmacist before use with '
          'stomach ulcers or asthma.',
    ),
    'cetirizine 10mg (generic tablet)': MedicineGuidance(
      howToUse: 'Swallow with water.',
      cautions: 'May cause drowsiness; avoid driving until you know how it '
          'affects you.',
    ),
    'virlix 10mg tablet (cetirizine)': MedicineGuidance(
      howToUse: 'Swallow with water.',
      cautions: 'May cause drowsiness.',
    ),
    'allerkid 5mg/5ml syrup 60ml': MedicineGuidance(
      howToUse: 'Measure with the supplied cup.',
      cautions: 'May cause drowsiness.',
    ),
    'solmux 500mg capsule (carbocisteine)': MedicineGuidance(
      howToUse: 'Take as directed on the label.',
      cautions: 'Check the label for ingredients you may also be taking.',
    ),
    'bioflu tablet': MedicineGuidance(
      howToUse: 'Take as directed on the label.',
      cautions: 'May cause drowsiness.',
    ),
  };

  /// The guidance for [name], or null when none is recorded.
  static MedicineGuidance? forName(String name) =>
      _byName[name.trim().toLowerCase()];
}
