import '../models/feature_entry.dart';
import 'feature_catalogue.dart';

/// The list of findable features.
///
/// Read-only, and there is deliberately no `FeatureStore` beside it. The
/// medicine feature splits its read interface from its write interface because
/// it has both; this one has nothing to write, nothing to sync, and no server
/// to lose. A store interface here would be an interface with no second
/// implementation and no second caller.
abstract interface class FeatureRepository {
  /// Every entry, ordered the way the finder shows them.
  List<FeatureEntry> all();

  /// Entries matching [query]. An empty query returns everything, in the same
  /// order as [all].
  List<FeatureEntry> search(String query);
}

/// The catalogue shipped in the binary.
///
/// Behind the interface so a test can hand over three entries instead of the
/// real list, and so a future version can read a remotely-updated catalogue
/// without the provider or the screen changing.
class StaticFeatureRepository implements FeatureRepository {
  const StaticFeatureRepository();

  @override
  List<FeatureEntry> all() => _sorted(featureCatalogue);

  @override
  List<FeatureEntry> search(String query) {
    if (query.trim().isEmpty) return all();
    return _sorted(featureCatalogue.where((entry) => entry.matches(query)));
  }

  /// Alphabetical by title, unmodifiable on every path.
  ///
  /// Unmodifiable even for the empty query, for the same reason
  /// `MedicineProvider.search` is: a screen that sorts its own results would
  /// otherwise reorder the repository's list in place, and the next caller
  /// would get it pre-sorted.
  ///
  /// Sorted on every call rather than cached. The list is under twenty entries
  /// and sorting it costs less than the bookkeeping a cache would need.
  static List<FeatureEntry> _sorted(Iterable<FeatureEntry> entries) {
    final sorted = entries.toList()..sort(FeatureEntry.compareByTitle);
    return List.unmodifiable(sorted);
  }
}
