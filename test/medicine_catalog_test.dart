import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_repository.dart';

void main() {
  const repository = StaticMedicineRepository();

  group('catalog', () {
    test('holds the transcribed list', () {
      expect(repository.all(), hasLength(64));
    });

    test('has no duplicate name+price pairs', () {
      final keys = repository.all().map(
        (m) => '${m.name.toLowerCase()}|${m.priceCentavos}',
      );

      expect(keys.toSet(), hasLength(keys.length));
    });

    test('keeps repeated names that have different prices', () {
      // These are separate products sharing a shorthand name, so collapsing
      // them would silently drop a real price.
      expect(repository.search('Amox'), hasLength(4));
      expect(repository.search('Diatabs'), hasLength(3));
      expect(repository.search('Tramadol'), hasLength(3));
      expect(repository.search('Tuseran'), hasLength(2));
    });

    test('formats the only price with centavos exactly', () {
      final geterizine = repository.all().firstWhere(
        (m) => m.name == 'GETERIZINE',
      );

      expect(geterizine.priceCentavos, 250);
      expect(geterizine.formattedPrice, '₱2.50');
    });

    test('formats whole prices to two decimals', () {
      final alcohol = repository.all().firstWhere((m) => m.name == 'Alcohol');

      expect(alcohol.formattedPrice, '₱65.00');
    });
  });

  group('search', () {
    test('an empty query returns everything', () {
      expect(repository.search(''), hasLength(64));
      expect(repository.search('   '), hasLength(64));
    });

    test('matches names case-insensitively', () {
      expect(repository.search('bIOgEsIc'), hasLength(1));
      expect(repository.search('biogesic').single.name, 'Biogesic');
    });

    test('matches on a substring, not just a prefix', () {
      expect(repository.search('syrup').map((m) => m.name), [
        'Cetirizine syrup',
        'Fern s syrup',
        'Para syrup',
      ]);
      expect(repository.search('roll').map((m) => m.name), ['Katinko roll']);
    });

    test('ignores spaces so babyoil finds "Baby Oil"', () {
      expect(repository.search('babyoil').single.name, 'Baby Oil');
    });

    test('matches on price with or without decimals', () {
      expect(repository.search('65.00').map((m) => m.name), [
        'Alcohol',
        'Alcohol med',
      ]);
      // Bare integers work too: the requirement is two or more digits.
      expect(repository.search('65').map((m) => m.name), [
        'Alcohol',
        'Alcohol med',
      ]);
      // Three items sit at 22.00, which is easy to get wrong by eye.
      expect(repository.search('₱22.00').map((m) => m.name), [
        'Alcohol small',
        'DIATABS',
        'Tuseran',
      ]);
    });

    test('a bare short number does not match prices', () {
      // '2' would otherwise flood the list with every cheap item on the shelf.
      final results = repository.search('2');
      final byPrice = results.where((m) => m.priceCentavos == 200).toList();

      expect(byPrice, isEmpty);
    });

    test('returns nothing for a query that matches nothing', () {
      expect(repository.search('zzzz'), isEmpty);
    });

    test('sorts by name ignoring case, then cheapest first', () {
      final names = repository.search('amox').map((m) => m.name).toList();

      expect(names, ['Amox', 'Amox', 'Amox 250 CAP', 'Amox 500mg']);
      final prices = repository
          .search('amox')
          .where((m) => m.name == 'Amox')
          .map((m) => m.priceCentavos);
      expect(prices, [400, 4500]);
    });

    test('the full list is alphabetical ignoring case', () {
      final names = repository.all().map((m) => m.name.toLowerCase()).toList();
      final sorted = names.toList()..sort();

      expect(names, sorted);
    });
  });

  group('stock', () {
    const empty = MedicineModel(name: 'X', priceCentavos: 100, stock: 0);
    const one = MedicineModel(name: 'X', priceCentavos: 100, stock: 1);
    const five = MedicineModel(name: 'X', priceCentavos: 100, stock: 5);
    const six = MedicineModel(name: 'X', priceCentavos: 100, stock: 6);
    const plenty = MedicineModel(name: 'X', priceCentavos: 100, stock: 40);

    test('is not part of item identity', () {
      // The one that matters most in this file. A shelf count is state, not
      // identity: a line added while an item was at 10 still has to be found
      // after the count moves to 9, which it will not be if stock leaks into
      // equality. Same name, same price, different count -- so the same item.
      const later = MedicineModel(name: 'X', priceCentavos: 100, stock: 9);

      expect(one, later);
      expect(one.hashCode, later.hashCode);
    });

    test('treats zero as out of stock, not merely low', () {
      expect(empty.isOutOfStock, isTrue);
      expect(empty.isLowStock, isFalse, reason: '"none" is not "a few"');
    });

    test('calls one to five low, and six or more healthy', () {
      expect(one.isLowStock, isTrue);
      expect(five.isLowStock, isTrue, reason: 'the threshold is inclusive');
      expect(six.isLowStock, isFalse);
      expect(plenty.isLowStock, isFalse);
      expect(five.isOutOfStock, isFalse);
    });

    test('reports a count and whether to colour it as a warning', () {
      expect(empty.stockLine, ('Out of stock', true));
      expect(one.stockLine, ('1 in stock · low', true));
      expect(five.stockLine, ('5 in stock · low', true));
      expect(six.stockLine, ('6 in stock', false));
      expect(plenty.stockLine, ('40 in stock', false));
    });

    test('a placeholder count is seeded for every line', () {
      expect(repository.all().where((m) => m.stock > 0), hasLength(57));
    });

    test('the seed covers all three states so each is reviewable', () {
      final all = repository.all();

      expect(all.where((m) => m.isOutOfStock), hasLength(7));
      expect(all.where((m) => m.isLowStock), hasLength(9));
    });
  });
}
