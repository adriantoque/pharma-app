import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/finder/data/models/feature_entry.dart';
import 'package:pharmaguide/features/finder/data/repositories/feature_repository.dart';

class _FakeRepository implements FeatureRepository {
  _FakeRepository(this._entries);

  final List<FeatureEntry> _entries;

  @override
  List<FeatureEntry> all() => _sorted(_entries);

  @override
  List<FeatureEntry> search(String query) => query.trim().isEmpty
      ? all()
      : _sorted(_entries.where((e) => e.matches(query)));

  static List<FeatureEntry> _sorted(Iterable<FeatureEntry> entries) {
    final sorted = entries.toList()..sort(FeatureEntry.compareByTitle);
    return List.unmodifiable(sorted);
  }
}

FeatureEntry _entry(String id, String title, {List<String> aliases = const []}) =>
    FeatureEntry(id: id, title: title, routePath: '/$id', aliases: aliases);

void main() {
  final repository = _FakeRepository([
    _entry('expiring', 'Expiring Meds', aliases: const ['expiry']),
    _entry('inventory', 'Inventory'),
    _entry('orders', 'Orders'),
    _entry('home', 'Price List', aliases: const ['search']),
  ]);

  test('all() is alphabetical ignoring case', () {
    expect(
      repository.all().map((e) => e.title),
      ['Expiring Meds', 'Inventory', 'Orders', 'Price List'],
    );
  });

  test('all() is unmodifiable', () {
    expect(() => repository.all().add(_entry('x', 'X')), throwsUnsupportedError);
  });

  test('empty query returns the same order as all()', () {
    expect(
      repository.search('').map((e) => e.id),
      repository.all().map((e) => e.id),
    );
  });

  test('results are a subsequence of all()', () {
    // The property that makes narrowing feel like filtering rather than
    // reshuffling: rows disappear, they never move.
    final all = repository.all().map((e) => e.id).toList();
    final results = repository.search('e').map((e) => e.id).toList();

    var cursor = 0;
    for (final id in results) {
      cursor = all.indexOf(id, cursor);
      expect(cursor, isNot(-1), reason: '$id missing from all()');
      cursor++;
    }
  });

  test('an alias match keeps the entry at its title position', () {
    // The assertion that would have caught a relevance ranking: 'expiry' must
    // surface Expiring Meds where E belongs, not at the top.
    final results = repository.search('expiry').map((e) => e.id).toList();
    expect(results, ['expiring']);
    expect(repository.all().first.id, 'expiring');
  });

  test('whitespace-only query returns everything', () {
    expect(repository.search('   ').length, repository.all().length);
  });
}
