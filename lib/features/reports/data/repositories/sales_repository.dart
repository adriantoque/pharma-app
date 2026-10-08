import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/sale_model.dart';

/// Totals for one report question.
@immutable
class SalesSummary {
  const SalesSummary({
    required this.units,
    required this.totalCentavos,
    required this.daysWithSales,
  });

  final num units;
  final int totalCentavos;

  /// Distinct calendar days in the period that have at least one sale.
  ///
  /// Counted rather than taken as the span of the period, because a pharmacy that
  /// sells nothing on a Sunday should pull the average down, and dividing by
  /// every calendar day in the range would quietly flatter the daily rate.
  final int daysWithSales;

  /// Units per day on the days there was trade.
  ///
  /// Zero when there was no trade at all, rather than a division by zero.
  num get unitsPerDay => daysWithSales == 0 ? 0 : units / daysWithSales;

  static const SalesSummary empty = SalesSummary(
    units: 0,
    totalCentavos: 0,
    daysWithSales: 0,
  );
}

/// One product's sales, rolled up across every spelling of its name.
@immutable
class ProductSales {
  const ProductSales({
    required this.key,
    required this.displayName,
    required this.units,
    required this.totalCentavos,
    required this.occurrences,
  });

  /// Normalised name, which is what the lines were grouped by.
  final String key;

  /// The spelling used most often, which is what a human would recognise.
  final String displayName;

  final num units;
  final int totalCentavos;

  /// How many separate sales lines this covers, which is not the same as
  /// [units]: a line can be a single unit or fifty.
  final int occurrences;

  static const ProductSales empty = ProductSales(
    key: '',
    displayName: '',
    units: 0,
    totalCentavos: 0,
    occurrences: 0,
  );
}

/// Sales history, read from the bundled seed.
///
/// Local rather than in Firestore on purpose. The workbook is a build-time input
/// and its several thousand lines describe months that have already happened, so
/// storing them would cost reads to answer a question whose answer never changes.
/// The reports screen therefore works with no network at all, and a report that
/// cannot be produced offline is a report nobody can produce at the counter.
class SalesRepository {
  const SalesRepository(this.sales);

  /// Every line, bundled.
  final List<SaleModel> sales;

  /// Loads the seed bundled at `assets/data/sales_seed.json` and merges with
  /// the cleaned CSV at `assets/data/cleaned_sales_seed.json`.
  static Future<SalesRepository> load() async {
    final salesSeedRaw = await rootBundle.loadString('assets/data/sales_seed.json');
    final salesSeedDecoded = jsonDecode(salesSeedRaw) as List<dynamic>;
    final originalSales = <SaleModel>[
      for (final entry in salesSeedDecoded)
        if (entry is Map<String, dynamic>) SaleModel.fromJson(entry),
    ];

    // Try loading the cleaned CSV data as a supplemental source.
    final cleanedSeedRaw = await rootBundle.loadString('assets/data/cleaned_sales_seed.json');
    final cleanedSeedDecoded = jsonDecode(cleanedSeedRaw) as List<dynamic>;
    final cleanedSales = <SaleModel>[
      for (final entry in cleanedSeedDecoded)
        if (entry is Map<String, dynamic>) SaleModel.fromJson(entry),
    ];

    // Merge: keep original sales, append cleaned sales that don't duplicate
    // by normalised key. Cleaned data takes precedence for overlapping keys.
    final seenKeys = <String>{};
    final merged = <SaleModel>[];
    // Add original sales first
    for (final sale in originalSales) {
      final key = sale.key;
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        merged.add(sale);
      }
    }
    // Add cleaned sales that don't duplicate original keys
    for (final sale in cleanedSales) {
      final key = sale.key;
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        merged.add(sale);
      }
    }

    return SalesRepository(merged);
  }

  bool get isEmpty => sales.isEmpty;

  /// Lines in [month], or all of them when [month] is null.
  List<SaleModel> inMonth(DateTime? month) {
    if (month == null) return sales;
    return sales
        .where((sale) => sale.date.year == month.year && sale.date.month == month.month)
        .toList();
  }

  /// The months the records cover, newest first, for a period picker.
  List<DateTime> get months {
    final seen = <String, DateTime>{};
    for (final sale in sales) {
      if (!sale.isOnARealDate) continue;
      final key = '${sale.date.year}-${sale.date.month}';
      seen.putIfAbsent(key, () => DateTime(sale.date.year, sale.date.month));
    }
    final months = seen.values.toList()..sort((a, b) => b.compareTo(a));
    return months;
  }

  /// First and last day with a dated sale, or null when there are none.
  (DateTime, DateTime)? get dateRange {
    final dated = sales.where((sale) => sale.isOnARealDate);
    if (dated.isEmpty) return null;
    var earliest = dated.first.date;
    var latest = dated.first.date;
    for (final sale in dated) {
      if (sale.date.isBefore(earliest)) earliest = sale.date;
      if (sale.date.isAfter(latest)) latest = sale.date;
    }
    return (earliest, latest);
  }

  /// Totals over [lines], optionally of one kind only.
  static SalesSummary summarise(
    List<SaleModel> lines, {
    SaleKind? kind,
  }) {
    final days = <DateTime>{};
    var units = 0.0;
    var centavos = 0;
    for (final sale in lines) {
      if (kind != null && sale.kind != kind) continue;
      if (sale.isOnARealDate) days.add(sale.day);
      units += sale.quantity;
      centavos += sale.totalCentavos;
    }
    return SalesSummary(
      units: units,
      totalCentavos: centavos,
      daysWithSales: days.length,
    );
  }

  /// The best sellers in [lines], most units first.
  ///
  /// Grouped by the normalised [SaleModel.key] so a month's `cetirizine` and
  /// `ceterizine` lines are one product rather than two, and named after the
  /// spelling that appears most often, since the most-used spelling is the one
  /// the counter would recognise.
  static List<ProductSales> topSellers(
    List<SaleModel> lines, {
    int limit = 20,
    SaleKind? kind,
  }) {
    final byKey = <String, _Accumulator>{};
    for (final sale in lines) {
      if (kind != null && sale.kind != kind) continue;
      final accumulator = byKey.putIfAbsent(sale.key, _Accumulator.new);
      accumulator.add(sale);
    }

    final products = byKey.entries
        .map((entry) => entry.value.toProductSales(key: entry.key))
        .toList()
      ..sort((a, b) {
        // Units first, because that is what a reorder list is for. Revenue breaks
        // ties, so two items with the same units come out in a defined order.
        final byUnits = b.units.compareTo(a.units);
        if (byUnits != 0) return byUnits;
        final byValue = b.totalCentavos.compareTo(a.totalCentavos);
        return byValue != 0
            ? byValue
            : a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });

    return products.take(limit).toList();
  }
}

/// Totals for one product while the lines are being folded together.
class _Accumulator {
  final Map<String, int> _spellings = {};
  num _units = 0;
  int _centavos = 0;
  int _occurrences = 0;

  void add(SaleModel sale) {
    _spellings[sale.rawName] = (_spellings[sale.rawName] ?? 0) + 1;
    _units += sale.quantity;
    _centavos += sale.totalCentavos;
    _occurrences++;
  }

  ProductSales toProductSales({required String key}) {
    // The spelling that appears on the most lines, with the name as the
    // tie-break so the result does not depend on map ordering.
    final display = _spellings.entries.toList()
      ..sort((a, b) =>
          b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
    return ProductSales(
      // The key the lines were actually grouped by, not the display name folded
      // to lower case: the two differ whenever the importer normalised a name to
      // something the sheet never wrote, and a caller looking a product up by this
      // key has to get the one that was grouped on.
      key: key,
      displayName: display.isEmpty ? '' : display.first.key,
      units: _units,
      totalCentavos: _centavos,
      occurrences: _occurrences,
    );
  }
}
