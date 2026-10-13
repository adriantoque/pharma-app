import '../../../../core/utils/search_text.dart';

/// One symptom a counter staff member can search for, and the medicines the
/// pharmacist has approved as self-care options for it.
///
/// The clinical text on this model -- [summary], and the directions held in
/// `MedicineGuidance` -- is supplied and reviewed by the pharmacist, not
/// authored by the app. The scaffold ships with clearly-marked placeholders
/// ([isDraft]) so the screens work end to end before that text lands; see
/// `symptom_catalogue.dart` for the format the text is pasted in.
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

  /// The medicines offered for this symptom, as names that must resolve in the
  /// live price list. The catalogue-integrity test holds this to that promise,
  /// so an entry cannot suggest a medicine the counter cannot actually sell.
  final List<String> medicineNames;

  /// When set, the symptom is one to hand to the pharmacist rather than treat
  /// at the counter, and the screen shows this note in place of self-care
  /// suggestions.
  final String? referralNote;

  /// Whether the clinical text is placeholder content awaiting pharmacist
  /// review. The screen shows a "draft" banner while this is true, so nobody
  /// mistakes scaffolding for advice.
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
