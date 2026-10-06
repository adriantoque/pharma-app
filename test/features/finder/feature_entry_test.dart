import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/finder/data/models/feature_entry.dart';

FeatureEntry _entry({
  required String id,
  required String title,
  List<String> aliases = const [],
  String? subtitle,
  String? parent,
}) => FeatureEntry(
  id: id,
  title: title,
  routePath: '/$id',
  aliases: aliases,
  subtitle: subtitle,
  parent: parent,
);

void main() {
  group('matches', () {
    final entry = _entry(
      id: 'expiring',
      title: 'Expiring Meds',
      subtitle: 'Lapsed and soon-to-lapse lines',
      aliases: const ['expiry', 'outdated'],
      parent: 'Home',
    );

    test('empty and whitespace queries match everything', () {
      expect(entry.matches(''), isTrue);
      expect(entry.matches('   '), isTrue);
    });

    test('punctuation-only queries match everything', () {
      // Normalises to empty. Matching nothing here would blank the list the
      // moment somebody typed a hyphen.
      expect(entry.matches('---'), isTrue);
    });

    test('title matches case- and punctuation-insensitively', () {
      expect(entry.matches('expiring'), isTrue);
      expect(entry.matches('EXPIRING'), isTrue);
      expect(entry.matches('expiring meds'), isTrue);
      expect(entry.matches('expiring-meds'), isTrue);
    });

    test('aliases match', () {
      expect(entry.matches('expiry'), isTrue);
      expect(entry.matches('outdated'), isTrue);
    });

    test('subtitle and parent match', () {
      expect(entry.matches('lapsed'), isTrue);
      expect(entry.matches('home'), isTrue);
    });

    test('unrelated text does not match', () {
      expect(entry.matches('inventory'), isFalse);
    });
  });

  group('compareByTitle', () {
    test('orders alphabetically ignoring case', () {
      final entries = [
        _entry(id: 'b', title: 'beta'),
        _entry(id: 'a', title: 'Alpha'),
        _entry(id: 'c', title: 'Charlie'),
      ]..sort(FeatureEntry.compareByTitle);

      expect(entries.map((e) => e.title), ['Alpha', 'beta', 'Charlie']);
    });

    test('breaks a title tie on id, deterministically', () {
      final entries = [
        _entry(id: 'zeta', title: 'Stock'),
        _entry(id: 'alpha', title: 'Stock'),
      ]..sort(FeatureEntry.compareByTitle);

      expect(entries.map((e) => e.id), ['alpha', 'zeta']);
    });
  });

  test('equality is by id, not title', () {
    final a = _entry(id: 'inventory', title: 'Inventory');
    final b = _entry(id: 'inventory', title: 'Stock Levels');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
