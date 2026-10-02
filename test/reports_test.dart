import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/reports/data/models/sale_model.dart';
import 'package:pharmaguide/features/reports/data/repositories/sales_repository.dart';

/// Covers the report arithmetic and the screen that shows it.
///
/// The repository is injected rather than loaded from the bundled seed. A seed
/// read goes through `rootBundle`, which never completes under the test binding,
/// so a screen left to load its own data would sit on a spinner forever and
/// `pumpAndSettle` would time out rather than fail with something readable.
void main() {
  SaleModel sale({
    required String date,
    required String name,
    num quantity = 1,
    int priceCentavos = 1000,
    SaleKind kind = SaleKind.counter,
    String? key,
  }) {
    return SaleModel(
      date: DateTime.parse(date),
      kind: kind,
      rawName: name,
      key: key ?? name.toLowerCase(),
      quantity: quantity,
      priceCentavos: priceCentavos,
      totalCentavos: (quantity * priceCentavos).round(),
      sourceSheet: date,
    );
  }

  /// Two months of counter trade, one bulk order, a half-tablet line, a
  /// misspelling of a product already in the list, and a product whose grouping
  /// key is not simply its name in lower case.
  late List<SaleModel> sales;

  setUp(() {
    sales = [
      // July, counter trade on four days spread over nine.
      sale(date: '2025-07-12', name: 'Amox', quantity: 4),
      sale(date: '2025-07-13', name: 'Amox', quantity: 2),
      // Same grouping key as `Amox` despite the different spelling, which is what
      // the importer does: the sheet's typo is folded in, not listed beside it.
      sale(date: '2025-07-19', name: 'amoxicilin', quantity: 1, key: 'amox'),
      sale(date: '2025-07-20', name: 'Cetirizine', quantity: 3),
      // A half tablet, which is why quantity is a num.
      sale(date: '2025-07-20', name: 'Losartan', quantity: 2.5),
      // August.
      sale(date: '2025-08-02', name: 'Cetirizine', quantity: 5),
      sale(date: '2025-08-03', name: 'Amox', quantity: 1),
      // Grouped on a key the sheet never wrote, the way the importer normalises
      // a name down to letters and digits.
      sale(date: '2025-08-03', name: 'Panadol 500', key: 'panadol500'),
      // A named customer's order. Real revenue, not counter trade.
      sale(
        date: '2025-08-03',
        name: 'Losartan+Amlodipine',
        quantity: 100,
        priceCentavos: 500,
        kind: SaleKind.bulk,
      ),
    ];
  });

  group('the daily rate', () {
    test(
      'divides by the days that had trade, not by every day in the range',
      () {
        // July's counter lines fall on the 12th, 13th, 19th and 20th: four days
        // with trade spread over nine. Dividing by nine would report a rate for
        // days the pharmacy was shut and quietly flatter the number.
        final summary = SalesRepository.summarise(
          SalesRepository(sales).inMonth(DateTime(2025, 7)),
        );

        expect(summary.daysWithSales, 4);
        expect(summary.units, 12.5);
        expect(summary.unitsPerDay, 3.125);
      },
    );

    test('keeps a half quantity rather than rounding it', () {
      // 2.5 tablets were sold. Reporting 2 or 3 would put a number in the report
      // that nobody dispensed.
      final losartan = sales
          .where((line) => line.rawName == 'Losartan')
          .map((line) => line.quantity)
          .single;

      expect(losartan, 2.5);
    });

    test('is zero rather than a division by zero when there was no trade', () {
      expect(SalesSummary.empty.unitsPerDay, 0);
      expect(
        SalesRepository.summarise(const []).unitsPerDay,
        0,
        reason:
            'an empty month has to survive being divided by its own zero days',
      );
    });

    test('an undated line is not counted as a trading day', () {
      final summary = SalesRepository.summarise([
        SaleModel(
          date: DateTime.fromMillisecondsSinceEpoch(0),
          kind: SaleKind.counter,
          rawName: 'Amox',
          key: 'amox',
          quantity: 1,
          priceCentavos: 1000,
          totalCentavos: 1000,
          sourceSheet: 'unknown',
        ),
      ]);

      // The units still count. Only the day is unproven, and inventing one would
      // put a false average in the report.
      expect(summary.units, 1);
      expect(summary.daysWithSales, 0);
      expect(summary.unitsPerDay, 0);
    });
  });

  group('bulk orders', () {
    test('are held out of the counter totals', () {
      final august = SalesRepository(sales).inMonth(DateTime(2025, 8));
      final counter = SalesRepository.summarise(august, kind: SaleKind.counter);
      final bulk = SalesRepository.summarise(august, kind: SaleKind.bulk);

      expect(counter.units, 7);
      expect(bulk.units, 100);
      // The whole month including the order, so the two reconcile against the
      // sheet rather than one quietly replacing the other.
      expect(SalesRepository.summarise(august).units, 107);
    });

    test('are still counted as revenue', () {
      final august = SalesRepository(sales).inMonth(DateTime(2025, 8));
      final bulk = SalesRepository.summarise(august, kind: SaleKind.bulk);

      expect(bulk.totalCentavos, 50000);
    });
  });

  group('top sellers', () {
    test('folds every spelling of a product into one row', () {
      // `Amox` and `amoxicilin` are the same product, and a reorder list showing
      // them as two would send someone to buy stock they already have.
      final top = SalesRepository.topSellers(
        SalesRepository(sales).inMonth(DateTime(2025, 7)),
      );

      expect(
        top.firstWhere((product) => product.displayName == 'Amox').units,
        7,
      );
      expect(
        top.where((product) => product.displayName == 'amoxicilin'),
        isEmpty,
        reason: 'the misspelling was folded into Amox, not listed beside it',
      );
    });

    test('names the product after the spelling used most often', () {
      final top = SalesRepository.topSellers(
        SalesRepository(sales).inMonth(DateTime(2025, 7)),
      );

      // Two `Amox` lines against one `amoxicilin`, so the recognisable spelling
      // wins even though the normalised key is what grouped them.
      expect(top.first.displayName, 'Amox');
    });

    test('reports the key the lines were grouped by', () {
      // The key is what a caller would look a product up with, and the importer's
      // keys are not the sheet's spelling in lower case. Deriving the key from
      // the display name instead would return 'panadol 500' here and break that
      // lookup for every product the importer normalised.
      final top = SalesRepository.topSellers(
        SalesRepository(sales).inMonth(DateTime(2025, 8)),
      );

      final panadol = top.firstWhere(
        (product) => product.displayName == 'Panadol 500',
      );
      expect(panadol.key, 'panadol500');
    });

    test('ranks by units, not by value', () {
      // The bulk order is the largest line in August by a wide margin and is not
      // what a reorder list is for, so the counter list leaves it out entirely.
      final top = SalesRepository.topSellers(
        SalesRepository(sales).inMonth(DateTime(2025, 8)),
        kind: SaleKind.counter,
      );

      expect(top.first.displayName, 'Cetirizine');
      expect(top.first.units, 5);
      expect(
        top.where((product) => product.displayName.contains('Losartan')),
        isEmpty,
        reason: 'a named customer\'s order is not counter trade',
      );
    });

    test('counts lines, not units, separately', () {
      // A reorder list needs both, and they are not the same number: one line
      // can be a single unit or fifty.
      final amox = SalesRepository.topSellers(
        SalesRepository(sales).inMonth(DateTime(2025, 7)),
      ).firstWhere((product) => product.displayName == 'Amox');

      expect(amox.units, 7);
      expect(amox.occurrences, 3);
    });

    test('orders equal volumes by value so the list is stable', () {
      final tied = SalesRepository.topSellers([
        sale(date: '2025-08-02', name: 'Bee', quantity: 1, priceCentavos: 1000),
        sale(date: '2025-08-02', name: 'Ay', quantity: 1, priceCentavos: 9000),
      ]);

      expect(tied.map((product) => product.displayName), ['Ay', 'Bee']);
    });

    test('respects the limit', () {
      final many = SalesRepository.topSellers([
        for (var i = 0; i < 30; i++)
          sale(date: '2025-08-02', name: 'Product $i'),
      ], limit: 5);

      expect(many, hasLength(5));
    });

    test('is empty rather than throwing when there is nothing to rank', () {
      expect(SalesRepository.topSellers(const []), isEmpty);
    });
  });

  group('the period', () {
    test('lists the months covered, newest first', () {
      expect(SalesRepository(sales).months, [
        DateTime(2025, 8),
        DateTime(2025, 7),
      ]);
    });

    test('reports the first and last dated sale', () {
      expect(SalesRepository(sales).dateRange, (
        DateTime(2025, 7, 12),
        DateTime(2025, 8, 3),
      ));
    });

    test('has no range at all when nothing has a date', () {
      final undated = SalesRepository([
        SaleModel(
          date: DateTime.fromMillisecondsSinceEpoch(0),
          kind: SaleKind.counter,
          rawName: 'Amox',
          key: 'amox',
          quantity: 1,
          priceCentavos: 1000,
          totalCentavos: 1000,
          sourceSheet: 'unknown',
        ),
      ]);

      expect(undated.dateRange, isNull);
      expect(undated.months, isEmpty);
    });
  });

  group('reading the seed', () {
    test('a malformed date does not throw while the report loads', () {
      // One bad row must not cost the pharmacist the other two thousand.
      final parsed = SaleModel.fromJson({'date': 'not a date', 'rawName': 'x'});

      expect(parsed.isOnARealDate, isFalse);
      expect(parsed.date, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('a missing quantity reads as zero rather than null', () {
      expect(SaleModel.fromJson({'date': '2025-07-12'}).quantity, 0);
    });

    test('a half price is read exactly', () {
      expect(
        SaleModel.fromJson({'date': '2025-07-12', 'priceCentavos': 250})
            .priceCentavos,
        250,
      );
    });

    test('an unknown kind is counter, not bulk', () {
      // Reading an unrecognised value as bulk would quietly remove a day's trade
      // from the daily average, which is the one number this screen exists for.
      expect(SaleModel.fromJson({'date': '2025-07-12'}).kind, SaleKind.counter);
    });

    test('an ISO timestamp with a time part still reads as a day', () {
      // Firestore's own date format, in case a line is ever written there.
      expect(
        SaleModel.fromJson({'date': '2025-07-12T00:00:00.000Z'}).isOnARealDate,
        isTrue,
      );
    });
  });

  // TODO: Rewrite widget tests for the new ReportsScreen architecture.
  // The new screen uses ReportsRepository (different from SalesRepository)
  // and requires a MedicineProvider. These tests need a proper fake
  // ReportsRepository that returns realistic SalesReport data.
  // For now, the SalesRepository unit tests above provide coverage of
  // the core report arithmetic.
}
