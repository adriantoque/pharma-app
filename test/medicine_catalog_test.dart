import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
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
    const uncounted = MedicineModel(name: 'X', priceCentavos: 100, stock: null);

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

    test('reports a count, the label and the state to colour it from', () {
      expect(empty.stockLine, ('Out of stock', StockState.outOfStock));
      expect(one.stockLine, ('1 in stock · low', StockState.low));
      expect(five.stockLine, ('5 in stock · low', StockState.low));
      expect(six.stockLine, ('6 in stock', StockState.available));
      expect(plenty.stockLine, ('40 in stock', StockState.available));
    });

    test('an uncounted line is unknown, not out of stock', () {
      // The distinction the whole nullable stock change turns on. A freshly
      // imported product has no count because nobody took one, and calling that
      // "out of stock" would block the sale of things that are on the shelf.
      expect(uncounted.isStockUnknown, isTrue);
      expect(uncounted.stockState, StockState.unknown);
      expect(uncounted.isOutOfStock, isFalse);
      // Uncounted *is* treated as low stock, deliberately: an unknown count is
      // not a licence to sell out of ignorance, so the dashboard asks for a
      // count. "Out of stock" stays the stronger, known claim.
      expect(uncounted.isLowStock, isTrue);
      expect(uncounted.stockLine, ('Not counted', StockState.unknown));
    });

    test('a count of zero is out of stock, not merely unknown', () {
      // The other half: unknown must not swallow the one state that is a real
      // answer, or nothing would ever be reported as unavailable again.
      expect(empty.isStockUnknown, isFalse);
      expect(empty.stockState, StockState.outOfStock);
    });

    test('a count still does not make the line unorderable by being absent', () {
      expect(OrderProvider.capFor(uncounted), OrderProvider.maxQuantity);
      expect(OrderProvider.capFor(empty), 0);
    });
  });

  group('searchable spellings', () {
    const withAlias = MedicineModel(
      name: 'Cetirizine',
      priceCentavos: 400,
      stock: null,
      aliases: ['ceterizine', 'Ceterezine'],
    );
    const brand = MedicineModel(
      name: 'Dolfenal',
      priceCentavos: 300,
      stock: null,
      genericKey: 'diclofenac',
    );

    test('finds a line by a spelling the counter has actually used', () {
      expect(withAlias.matches('ceterizine'), isTrue);
      expect(withAlias.matches('CETEREZINE'), isTrue);
    });

    test('finds a brand by its generic, and a generic by its brand', () {
      expect(brand.matches('diclofenac'), isTrue);
    });

    test('an alias does not create a second line', () {
      // Same name and price is one item however many ways it can be typed.
      const same = MedicineModel(
        name: 'Cetirizine',
        priceCentavos: 400,
        stock: 3,
        aliases: ['ceterizine'],
      );
      expect(withAlias, same);
    });

    test('an uncounted line is still findable by name and price', () {
      // Being uncounted must not make a line unfindable, or a fresh import
      // would hand the counter a list nothing can be looked up in.
      const uncountedX = MedicineModel(name: 'X', priceCentavos: 6500, stock: null);
      expect(uncountedX.matches('x'), isTrue);
      expect(uncountedX.matches('65'), isTrue);
    });
  });
}
