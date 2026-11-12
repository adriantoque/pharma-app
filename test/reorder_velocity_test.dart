import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/utils/search_text.dart';
import 'package:pharmaguide/features/orders/data/models/order_history_model.dart';
import 'package:pharmaguide/features/orders/data/models/order_line_model.dart';
import 'package:pharmaguide/features/reports/data/models/sale_model.dart';
import 'package:pharmaguide/features/reports/domain/reorder_velocity.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';

/// Fixture builders. Kept here rather than shared helpers because the sale and
/// order shapes only appear in this file's tests.
SaleModel _sale(
  String rawName, {
  required int day,
  num quantity = 1,
  SaleKind kind = SaleKind.counter,
}) {
  return SaleModel(
    date: DateTime(2026, 1, day),
    kind: kind,
    rawName: rawName,
    key: normaliseForSearch(rawName),
    quantity: quantity,
    priceCentavos: 0,
    totalCentavos: 0,
    sourceSheet: 'test',
  );
}

OrderHistory _order(
  String id,
  int day, {
  required List<(String name, int quantity)> lines,
  OrderStatus status = OrderStatus.approved,
}) {
  return OrderHistory(
    id: id,
    time: DateTime(2026, 1, day, 10),
    status: status,
    items: [
      for (final (name, quantity) in lines)
        OrderLineModel(
          medicine: MedicineModel(name: name, priceCentavos: 0, stock: null),
          quantity: quantity,
        ),
    ],
    totalCentavos: 0,
  );
}

void main() {
  group('usageBySaleKey', () {
    test('groups lines by normalised key and sums units', () {
      final usage = usageBySaleKey([
        _sale('Cetirizine', day: 1, quantity: 2),
        _sale('cetirizine', day: 2, quantity: 3),
      ]);

      expect(usage, hasLength(1));
      expect(usage['cetirizine']!.units, 5);
      expect(usage['cetirizine']!.daysWithSales, 2);
      expect(usage['cetirizine']!.unitsPerDay, 2.5);
    });

    test('a line with an unreal date is skipped entirely', () {
      // The tolerant parser turns a broken date into the epoch; counting it
      // would add a phantom day to the average.
      final broken = SaleModel(
        date: DateTime.fromMillisecondsSinceEpoch(0),
        kind: SaleKind.counter,
        rawName: 'Paracetamol',
        key: 'paracetamol',
        quantity: 10,
        priceCentavos: 0,
        totalCentavos: 0,
        sourceSheet: 'test',
      );

      expect(usageBySaleKey([broken]), isEmpty);
    });

    test('two sales on one day count one trading day', () {
      final usage = usageBySaleKey([
        _sale('Paracetamol', day: 1, quantity: 1),
        _sale('Paracetamol', day: 1, quantity: 4),
        _sale('Paracetamol', day: 2, quantity: 1),
      ]);

      expect(usage['paracetamol']!.daysWithSales, 2);
      expect(usage['paracetamol']!.units, 6);
      expect(usage['paracetamol']!.unitsPerDay, 3);
    });
  });

  group('usageByOrderKey', () {
    test('only approved orders feed the rate', () {
      final usage = usageByOrderKey([
        _order('a', 1, lines: [('Paracetamol', 5)]),
        _order('b', 2, lines: [('Paracetamol', 9)]),
        _order(
          'c',
          3,
          lines: [('Paracetamol', 50)],
          status: OrderStatus.rejected,
        ),
        _order(
          'd',
          4,
          lines: [('Paracetamol', 20)],
          status: OrderStatus.new_,
        ),
      ]);

      // The rejected and pending orders were never sales; counting them
      // would size the reorder for demand that did not happen.
      expect(usage['paracetamol']!.units, 14);
    });

    test('orders group under the same normalised key as sale lines', () {
      final usage = usageByOrderKey([
        _order('a', 1, lines: [('Cetirizine 10mg', 2)]),
        _order('b', 3, lines: [('cetirizine 10mg', 1)]),
      ]);

      // The same key space as usageBySaleKey: a lookup by the normalised
      // medicine name finds the order history's rate.
      expect(usage['cetirizine10mg']!.units, 3);
    });
  });

  group('unitsPerDayForMedicine', () {
    test('live history wins over the bundled seed for the same key', () {
      final medicine = MedicineModel(
        name: 'Paracetamol',
        priceCentavos: 0,
        stock: null,
      );
      final live = {
        'paracetamol': const SalesUsage(units: 10, daysWithSales: 5),
      };
      final seed = {
        'paracetamol': const SalesUsage(units: 100, daysWithSales: 5),
      };

      // Summing the two sources would double-count any month both covered;
      // the live one is the picture of what is moving now.
      expect(unitsPerDayForMedicine(medicine, live, seed), 2);
    });

    test('the seed is the fallback when live history has nothing', () {
      final medicine = MedicineModel(
        name: 'Cetirizine',
        priceCentavos: 0,
        stock: null,
      );

      expect(
        unitsPerDayForMedicine(
          medicine,
          const {},
          {
            'cetirizine': const SalesUsage(units: 30, daysWithSales: 10),
          },
        ),
        3,
      );
    });

    test('an alias spelling resolves to the line the list carries', () {
      final medicine = MedicineModel(
        name: 'Cetirizine',
        priceCentavos: 0,
        stock: null,
        aliases: ['ceterizine'],
      );
      final seed = {
        'ceterizine': const SalesUsage(units: 12, daysWithSales: 6),
      };

      // The counter writes the alias; the velocity belongs to the line the
      // catalogue actually stocks.
      expect(unitsPerDayForMedicine(medicine, const {}, seed), 2);
    });

    test('no data anywhere is zero, not a crash', () {
      final medicine = MedicineModel(
        name: 'Ibuprofen',
        priceCentavos: 0,
        stock: null,
      );

      expect(unitsPerDayForMedicine(medicine, const {}, const {}), 0);
    });

    test('a usage with no trading days does not count as data', () {
      final medicine = MedicineModel(
        name: 'Ibuprofen',
        priceCentavos: 0,
        stock: null,
      );
      final live = {
        'ibuprofen': const SalesUsage(units: 0, daysWithSales: 0),
      };

      expect(unitsPerDayForMedicine(medicine, live, const {}), 0);
    });
  });

  group('reorderTarget', () {
    test('coverage of the observed rate, rounded up', () {
      expect(
        reorderTarget(
          unitsPerDay: 6.4,
          coverageDays: 14,
          threshold: 5,
        ),
        90,
        reason: 'ceil(6.4 x 14) = 90',
      );
      expect(
        reorderTarget(
          unitsPerDay: 0.7,
          coverageDays: 10,
          threshold: 5,
        ),
        7,
        reason: 'ceil(0.7 x 10) = 7',
      );
    });

    test('never below the low-stock threshold', () {
      // A slow mover with target 0 would sit on the alert list with a
      // deficit of 0 -- an alert with nothing to act on. The floor keeps
      // every row actionable.
      expect(
        reorderTarget(
          unitsPerDay: 0.5,
          coverageDays: 7,
          threshold: 5,
        ),
        5,
      );
      expect(
        reorderTarget(unitsPerDay: 0, coverageDays: 14, threshold: 5),
        5,
      );
    });

    test('whole arithmetic that lands exactly on the threshold stays there', () {
      expect(
        reorderTarget(unitsPerDay: 1, coverageDays: 5, threshold: 5),
        5,
      );
    });
  });
}
