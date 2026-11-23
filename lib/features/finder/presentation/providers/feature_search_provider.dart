import 'package:flutter/foundation.dart';

import '../../data/models/feature_entry.dart';
import '../../data/repositories/feature_repository.dart';

/// What the feature finder is currently showing.
///
/// Holds the query and the filtered list, and nothing else. There is no loading
/// flag and no error field, because the catalogue is in the binary: the first
/// read cannot fail and cannot be slow, so a spinner would be a state that is
/// set once and never seen. The medicine provider needs both because it has a
/// server; this one has a `const` list.
class FeatureSearchProvider extends ChangeNotifier {
  FeatureSearchProvider({
    FeatureRepository repository = const StaticFeatureRepository(),
  }) : // A named parameter cannot be private, so `this._repository` is not
       // available and this is the only shape it can take.
       // ignore: prefer_initializing_formals
       _repository = repository;

  final FeatureRepository _repository;

  String _query = '';
  List<FeatureEntry>? _cached;

  /// What the user has typed.
  String get query => _query;

  /// Whether the query is empty or whitespace only.
  ///
  /// Trimmed, so a field holding three spaces reads as empty. The screen uses
  /// this to decide whether to show "no match" -- a query of spaces matches
  /// everything and must not produce that message.
  bool get isUnfiltered => _query.trim().isEmpty;

  /// The entries to show, already ordered.
  ///
  /// Computed on first read after a query change and held until the next one.
  /// Rebuilding on every access would re-filter and re-sort twenty entries on
  /// every frame that touches this provider, which is most of them while
  /// somebody is typing.
  List<FeatureEntry> get results => _cached ??= _repository.search(_query);

  int get resultCount => results.length;

  /// Whether a query is typed and it matched nothing.
  bool get hasNoMatches => !isUnfiltered && results.isEmpty;

  void updateQuery(String value) {
    // Guarded because `onChanged` fires for programmatic edits too, and
    // notifying on an unchanged query rebuilds every listener for nothing.
    if (_query == value) return;
    _query = value;
    _cached = null;
    notifyListeners();
  }

  void clear() => updateQuery('');
}
