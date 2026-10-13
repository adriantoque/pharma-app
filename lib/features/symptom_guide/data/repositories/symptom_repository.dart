import '../models/symptom_entry.dart';
import 'symptom_catalogue.dart';

/// The symptom guide's content, behind an interface.
///
/// An interface rather than a bare `const` list so the screens can be tested
/// against a fixture without reaching into the production catalogue, matching
/// `FeatureRepository` on the finder side.
abstract interface class SymptomRepository {
  /// Every symptom, ordered for display.
  List<SymptomEntry> all();

  /// The symptoms matching [query], ordered for display. An empty query returns
  /// everything.
  List<SymptomEntry> search(String query);

  /// The symptom with [id], or null when there is none.
  SymptomEntry? byId(String id);
}

/// The [SymptomRepository] over the bundled, in-binary catalogue.
///
/// No loading and no error state: the catalogue is in the binary, so the first
/// read cannot fail and cannot be slow. A spinner would be a state that is set
/// once and never seen.
class StaticSymptomRepository implements SymptomRepository {
  const StaticSymptomRepository();

  @override
  List<SymptomEntry> all() =>
      List.of(symptomCatalogue)..sort(SymptomEntry.compareByName);

  @override
  List<SymptomEntry> search(String query) =>
      symptomCatalogue.where((entry) => entry.matches(query)).toList()
        ..sort(SymptomEntry.compareByName);

  @override
  SymptomEntry? byId(String id) {
    for (final entry in symptomCatalogue) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}
