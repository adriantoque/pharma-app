import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/finder/data/repositories/feature_catalogue.dart';
import 'package:pharmaguide/features/finder/presentation/widgets/feature_row.dart';

void main() {
  test('every route path starts with a slash and has no trailing slash', () {
    for (final entry in featureCatalogue) {
      expect(entry.routePath, startsWith('/'), reason: entry.id);
      expect(entry.routePath, isNot(endsWith('/')), reason: entry.id);
    }
  });

  test('every id is unique', () {
    final ids = featureCatalogue.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every icon key resolves to a real icon', () {
    // A typo'd key silently falls back to a generic icon, which nobody notices
    // until a user asks why Inventory and Reports have the same picture.
    for (final entry in featureCatalogue) {
      if (entry.iconKey == null) continue;
      expect(knownIconKeys, contains(entry.iconKey), reason: entry.id);
    }
  });
}
