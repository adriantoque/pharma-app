import '../../../../core/utils/search_text.dart';
import '../../../search/data/models/medicine_model.dart';

/// One symptom a counter staff member can search for, and the medicines the
/// pharmacist has approved as self-care options for it.
///
/// The clinical text on this model -- [summary], and the directions held in
/// `MedicineGuidance` -- is supplied and reviewed by the pharmacist, not
/// authored by the app. See `symptom_catalogue.dart` for the format the text is
/// stored in.
///
/// Deliberately not a `FeatureEntry` with a different name. A feature is a
/// screen the user jumps to; a symptom is clinical content matched to a
/// medicine. Sharing a model would mean one of the two carrying fields it never
/// uses.
class SymptomEntry {
  const SymptomEntry({
    required this.id,
    required this.name,
    required this.summary,
    this.aliases = const [],
    this.medicineNames = const [],
    this.referralNote,
    this.isDraft = false,
  });

  /// Hand-assigned, unique, and stable: `fever`, `headache`.
  ///
  /// Hand-written rather than derived from [name] because the name is the thing
  /// most likely to be reworded, and a derived id that changed with it would
  /// silently invalidate any saved reference to this entry.
  final String id;

  /// The name shown on the row and the primary thing [matches] searches.
  final String name;

  /// One or two sentences of context, including when to send the customer to
  /// the pharmacist.
  final String summary;

  /// Other words staff would plausibly type: `lagnat` for `Fever`, `ubo` for
  /// `Cough`.
  ///
  /// Only ever synonyms, never a second name. An alias that names a different
  /// symptom is how a search result sends somebody to the wrong advice.
  final List<String> aliases;

  /// The pharmacist's picks for this symptom, as names matched against the live
  /// price list. A name that does not resolve is simply skipped, so a pick for a
  /// product the counter has stopped stocking can stay here without breaking the
  /// screen.
  ///
  /// These lead the guide and are unioned with whatever the catalogue itself
  /// evidences through `MedicineModel.usageIndication`; see [recommendationsIn].
  /// The catalogue-integrity test holds every name to resolving in
  /// `assets/data/medicines_seed.json`.
  final List<String> medicineNames;

  /// When set, the symptom is one to hand to the pharmacist rather than treat
  /// at the counter, and the screen shows this note in place of self-care
  /// suggestions.
  final String? referralNote;

  /// Whether the clinical text is still awaiting pharmacist review, so an
  /// unreviewed entry can be told apart from an approved one. Defaults to false.
  final bool isDraft;

  /// Whether this entry should appear for [query].
  ///
  /// Matches the name and the aliases, not [summary]: the summary is prose, and
  /// searching it would make typing `fever` match every entry that happens to
  /// mention fever in a sentence -- which is most of them.
  ///
  /// An empty query matches everything, so the unfiltered list and the filtered
  /// list are the same code path, exactly as the finder and the medicine search
  /// behave.
  bool matches(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return true;

    final needle = normaliseForSearch(trimmed);
    // A query of nothing but punctuation normalises to empty. Treating that as
    // "match nothing" would blank the list the moment somebody typed a hyphen;
    // treating it as "match everything" keeps the list where it was.
    if (needle.isEmpty) return true;

    for (final candidate in searchableNames) {
      if (normaliseForSearch(candidate).contains(needle)) return true;
    }
    return false;
  }

  /// Everything this entry can be found by.
  ///
  /// One getter so the row and the provider cannot disagree about which
  /// spellings count -- the same reason `MedicineModel.searchableNames` and
  /// `FeatureEntry.searchableNames` exist.
  Iterable<String> get searchableNames => [name, ...aliases];

  /// The words that, found in a medicine's usage indication, mark it as
  /// treating this symptom: the name and its aliases, the same breadth [matches]
  /// searches so typing and suggesting cannot disagree.
  Iterable<String> get indicationTerms => [name, ...aliases];

  /// The medicines to offer for this symptom out of [catalogue].
  ///
  /// Two sources, so the pharmacist's curation leads and the data fills in
  /// behind it:
  ///
  /// 1. [medicineNames], resolved by exact name, in the order they were written.
  /// 2. Anything whose usage indication names this symptom or one of its
  ///    aliases (see `MedicineModel.matchesIndication`).
  ///
  /// The catalogue is first collapsed to one row per name -- several rows can
  /// share a name (a piece, a blister, a box) and the guide wants one card per
  /// medicine -- keeping the row a customer could actually be handed: in stock
  /// first, then cheapest. The two sources are then unioned with the curated
  /// picks ahead of the indication matches, which are sorted by name.
  List<MedicineModel> recommendationsIn(Iterable<MedicineModel> catalogue) {
    // One row per name, the orderable and cheapest one.
    final bestByName = <String, MedicineModel>{};
    for (final medicine in catalogue) {
      final key = medicine.name.trim().toLowerCase();
      final existing = bestByName[key];
      bestByName[key] = existing == null
          ? medicine
          : _betterOf(existing, medicine);
    }

    final result = <MedicineModel>[];
    final used = <String>{};

    // The pharmacist's picks, in their order, and only when stocked.
    for (final name in medicineNames) {
      final key = name.trim().toLowerCase();
      final medicine = bestByName[key];
      if (medicine != null && used.add(key)) result.add(medicine);
    }

    // Then whatever the catalogue itself says treats this symptom.
    final terms = indicationTerms.toList(growable: false);
    final extra = [
      for (final entry in bestByName.entries)
        if (!used.contains(entry.key) &&
            terms.any(entry.value.matchesIndication))
          entry.value,
    ]..sort(MedicineModel.compareByNameThenPrice);

    return [...result, ...extra];
  }

  /// The row to keep when two share a name: the one the counter can hand over
  /// first, then the cheaper. Ties keep [a], so the first seen wins.
  static MedicineModel _betterOf(MedicineModel a, MedicineModel b) {
    final aOrderable = !a.isOutOfStock;
    final bOrderable = !b.isOutOfStock;
    if (aOrderable != bOrderable) return bOrderable ? b : a;
    return b.priceCentavos < a.priceCentavos ? b : a;
  }

  /// The order the guide shows entries in: alphabetical by name, ignoring case,
  /// with [id] as the tiebreaker so the sort is total.
  static int compareByName(SymptomEntry a, SymptomEntry b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  /// Two entries are the same when their [id] matches, for the reason on [id].
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SymptomEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SymptomEntry($id)';
}
