import '../../../../core/utils/search_text.dart';

/// One row in the feature finder: a screen (or, later, an action) the user can
/// jump to by typing part of its name.
///
/// Deliberately not a [MedicineModel] with a different name. A medicine is
/// identified by name *and* price and is matched against a catalogue of
/// hundreds; a feature has no price, is identified by a hand-written [id], and
/// is matched against a list short enough to read. Sharing a model would mean
/// one of the two carrying fields it never uses.
class FeatureEntry {
  const FeatureEntry({
    required this.id,
    required this.title,
    required this.routePath,
    this.subtitle,
    this.aliases = const [],
    this.parent,
    this.iconKey,
  });

  /// Hand-assigned, unique, and stable across releases: `inventory`, `expiring`.
  ///
  /// Hand-written rather than derived from [title] because a title is the thing
  /// most likely to be reworded, and a derived id that changed with it would
  /// silently invalidate any saved reference to this entry -- a recent-items
  /// list, a test fixture, a deep link.
  final String id;

  /// The name shown on the row and the primary thing [matches] searches.
  final String title;

  /// One line of explanation, shown under the title.
  final String? subtitle;

  /// Where tapping this row goes. Resolved by `go_router`, so it has to be a
  /// path the router actually serves -- see [FeatureRoutes] for the one place
  /// these are written down.
  final String routePath;

  /// Other words staff would plausibly type for this screen: `expiry` for
  /// `Expiring Meds`, `stock` for `Inventory`.
  ///
  /// Only ever *synonyms and the words a user would reach for*, never a second
  /// title. An alias that names a different screen is how a search result sends
  /// somebody to the wrong place, which is worse here than not finding the
  /// entry at all.
  final List<String> aliases;

  /// The section this entry belongs to: `Dashboard`, `Reports`, `Account`.
  ///
  /// Carried on the model but unused by the flat list this feature ships with.
  /// It is here so grouping later is a change to the provider rather than a
  /// change to every entry, and so the value is filled in while somebody still
  /// remembers which screen sits where.
  final String? parent;

  /// Which icon the row draws, resolved to an `IconData` in the presentation
  /// layer.
  ///
  /// A string rather than an `IconData` because `IconData` is Flutter and this
  /// file is under `data/models/`, which by this project's rule stays free of
  /// Flutter imports. The lookup table lives in `feature_row.dart`, where
  /// `package:flutter/material.dart` is already imported for other reasons.
  final String? iconKey;

  /// Whether this entry should appear for [query].
  ///
  /// Four ways to hit: the title, the subtitle, an alias, or the parent section
  /// name. Matching the subtitle is a judgement call -- it means typing `lapsed`
  /// finds `Expiring Meds`, at the cost of typing `list` finding every entry
  /// whose subtitle happens to contain the word. Drop `subtitle` from
  /// [searchableNames] if that trade turns out wrong in use; it is one line.
  ///
  /// An empty query matches everything, which is what makes the unfiltered list
  /// and the filtered list the same code path -- see
  /// [StaticFeatureRepository.search].
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
  /// One getter so the row, the provider and any future suggestion UI cannot
  /// disagree about which spellings count -- the same reason
  /// `MedicineModel.searchableNames` exists.
  Iterable<String> get searchableNames =>
    [title, ?subtitle, ...aliases, ?parent];

  /// The order the finder shows entries in: alphabetical by title, ignoring
  /// case, with [id] as the tiebreaker.
  ///
  /// Sorted on [title] rather than [id] or [routePath] because the title is what
  /// the user is reading; sorting on anything else produces an order that looks
  /// arbitrary on screen even though it is deterministic in code.
  ///
  /// [id] breaks ties so the sort is total. Two entries sharing a title would
  /// otherwise come back in whatever order the source list happened to be in,
  /// which differs between the bundled catalogue and a test fixture and makes an
  /// order-sensitive test fail for a reason nobody can see.
  ///
  /// Case is folded with [String.toLowerCase], which is not locale-aware. That
  /// is correct for this app's Philippine English and is worth leaving alone:
  /// a locale-aware fold would reorder the existing list on a Turkish device,
  /// which is a change nobody asked for and no test would catch.
  static int compareByTitle(FeatureEntry a, FeatureEntry b) {
    final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
  }

  /// Two entries are the same when their [id] matches.
  ///
  /// [id] rather than [title] because the id is the stable handle, and because
  /// the finder never needs to ask "are these the same screen under a different
  /// name" -- if a screen is renamed, the id stays and the entry is the same one.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FeatureEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FeatureEntry($id -> $routePath)';
}
