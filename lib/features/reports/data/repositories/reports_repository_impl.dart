import 'dart:async';

import '../../../admin/data/models/store_settings_model.dart';
import '../../../orders/data/models/order_history_model.dart';
import '../../../orders/data/repositories/order_history_repository.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../domain/reorder_velocity.dart';
import '../models/report_range.dart';
import '../models/sales_report.dart';
import '../models/stock_alert.dart';
import '../models/expiry_alert.dart';
import 'reports_repository.dart';
import 'sales_repository.dart';

/// Implementation of [ReportsRepository] using existing providers.
class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl({
    required this.medicineProvider,
    required this.historyFactory,
    Future<SalesRepository?> Function()? salesLoader,
  }) : salesLoader = salesLoader ?? loadBundledSales;

  /// Public so the parameter and the field can be the same name; a private
  /// field behind a public parameter cannot be an initializing formal.
  final MedicineProvider medicineProvider;
  final OrderHistoryRepository Function() historyFactory;

  /// Produces the bundled sales history the velocity falls back on, or null
  /// when there is none. Injectable so tests can hand over a tiny fixed
  /// history instead of the 2000-line asset, and so a test can assert what
  /// happens when the seed is missing entirely.
  final Future<SalesRepository?> Function() salesLoader;

  /// The bundled sales history, loaded once per process.
  ///
  /// Static rather than per-instance: the seed never changes at runtime, and
  /// the app builds this repository above the router where a second instance
  /// would otherwise pay the asset parse again.
  static SalesRepository? _bundledCache;

  static Future<SalesRepository?> loadBundledSales() async {
    final cached = _bundledCache;
    if (cached != null) return cached;
    try {
      _bundledCache = await SalesRepository.load();
    } catch (_) {
      // A missing or unreadable seed is not a broken screen: the reorder
      // targets fall back to the threshold floor and the alerts still list.
      _bundledCache = null;
    }
    return _bundledCache;
  }

  /// Margin assumed when reporting profit.
  ///
  /// The price list carries a selling price and no cost price, so there is no
  /// figure to compute real profit from. Rather than leave the metric out or
  /// invent a cost per line, profit is shown as revenue times this fixed
  /// assumption, and the screen says so beside the number. If a cost price is
  /// ever added to [MedicineModel], this constant goes away and profit is
  /// summed from the lines instead.
  static const double assumedProfitMargin = 0.22;

  @override
  Future<SalesReport> getSalesReport(ReportRange range) async {
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day);
    final startDate = endDate.subtract(Duration(days: range.days - 1));

    // Fetch approved orders from history
    final history = historyFactory();
    final snapshot = await history.watchAll().first;

    // Filter to approved orders within the date range
    final completedOrders = snapshot.where((order) {
      if (order.status != OrderStatus.approved) return false;
      final orderDay = DateTime(order.time.year, order.time.month, order.time.day);
      return !orderDay.isBefore(startDate) && !orderDay.isAfter(endDate);
    }).toList();

    final dailySales = _aggregateDailySales(
      completedOrders,
      startDate,
      endDate,
    );
    final topSellers = _calculateTopSellers(completedOrders);
    final categorySales = _calculateCategorySales(completedOrders);

    final totalRevenue = completedOrders.fold(0, (sum, o) => sum + o.totalCentavos);
    final totalOrders = completedOrders.length;
    final totalItems = completedOrders.fold(0, (sum, o) => sum + o.items.length);

    return SalesReport(
      range: range,
      generatedAt: DateTime.now(),
      dailySales: dailySales,
      topSellers: topSellers,
      categorySales: categorySales,
      totalRevenue: totalRevenue,
      totalOrders: totalOrders,
      totalItems: totalItems,
      profitMargin: assumedProfitMargin,
    );
  }

  @override
  Future<List<StockAlert>> getLowStockAlerts({
    int coverageDays = StoreSettingsModel.defaultReorderCoverageDays,
  }) async {
    final medicines = medicineProvider.all();

    // Two velocity sources, live preferred. The history read uses the same
    // per-user factory the sales report does, so the rate an item's target is
    // built from is the rate this account's orders actually moved.
    final liveUsage = usageByOrderKey(await _approvedOrders());
    final seed = await salesLoader();
    final seedUsage = seed == null
        ? const <String, SalesUsage>{}
        : usageBySaleKey(seed.sales);

    final alerts = <StockAlert>[];

    for (final med in medicines) {
      if (med.isLowStock || med.isOutOfStock) {
        final unitsPerDay = unitsPerDayForMedicine(med, liveUsage, seedUsage);
        alerts.add(
          StockAlert(
            name: med.name,
            currentStock: med.stock ?? 0,
            reorderLevel: reorderTarget(
              unitsPerDay: unitsPerDay,
              coverageDays: coverageDays,
              threshold: MedicineModel.lowStockThreshold,
            ),
            category: _inferCategory(med.name),
            unitsPerDay: unitsPerDay,
            coverageDays: coverageDays,
            isStockUncounted: med.stock == null,
          ),
        );
      }
    }

    // Sort: out of stock first, then the biggest shortfall -- "how much do I
    // need" in the order a reorder would be placed in. Uncounted lines carry
    // currentStock 0 and land in the first group beside the true zeros, which
    // is the pre-existing treatment: they need counting as much as the empty
    // shelf needs filling.
    alerts.sort((a, b) {
      if (a.currentStock == 0 && b.currentStock != 0) return -1;
      if (a.currentStock != 0 && b.currentStock == 0) return 1;
      return b.deficit.compareTo(a.deficit);
    });

    return alerts;
  }

  /// Approved orders only, as one snapshot. Rejected orders were never sold
  /// and a pending one may still not be, so neither may size a reorder.
  Future<List<OrderHistory>> _approvedOrders() async {
    final snapshot = await historyFactory().watchAll().first;
    return snapshot
        .where((order) => order.status == OrderStatus.approved)
        .toList();
  }

  @override
  Future<List<ExpiryAlert>> getExpiryAlerts({int withinDays = 90}) async {
    final medicines = medicineProvider.all();
    final alerts = <ExpiryAlert>[];

    for (final med in medicines) {
      if (med.expiryDate != null) {
        final daysUntil = med.daysUntilExpiry;
        if (daysUntil != null && daysUntil <= withinDays) {
          alerts.add(
            ExpiryAlert(
              name: med.name,
              expiryDate: med.expiryDate ?? DateTime.now(),
              quantity: med.stock ?? 0,
              category: _inferCategory(med.name),
            ),
          );
        }
      }
    }

    // Sort: expired first, then by days until expiry
    alerts.sort((a, b) {
      if (a.isExpired && !b.isExpired) return -1;
      if (!a.isExpired && b.isExpired) return 1;
      return a.expiryDate.compareTo(b.expiryDate);
    });

    return alerts;
  }

  List<DailySales> _aggregateDailySales(
    List<OrderHistory> orders,
    DateTime startDate,
    DateTime endDate,
  ) {
    final dailyMap = <DateTime, int>{};

    for (final order in orders) {
      final dayKey = DateTime(
        order.time.year,
        order.time.month,
        order.time.day,
      );
      dailyMap[dayKey] = (dailyMap[dayKey] ?? 0) + order.totalCentavos;
    }

    final dailySales = <DailySales>[];
    var current = startDate;
    while (!current.isAfter(endDate)) {
      dailySales.add(DailySales(date: current, amount: dailyMap[current] ?? 0));
      current = current.add(const Duration(days: 1));
    }

    return dailySales;
  }

  List<TopSeller> _calculateTopSellers(List<OrderHistory> orders) {
    final itemRevenue = <String, int>{};
    final itemQty = <String, int>{};
    final itemUnit = <String, String>{};

    for (final order in orders) {
      for (final item in order.items) {
        final currentRevenue = itemRevenue[item.medicine.name] ?? 0;
        itemRevenue[item.medicine.name] =
            currentRevenue + item.totalCentavos;
        itemQty[item.medicine.name] =
            (itemQty[item.medicine.name] ?? 0) + item.quantity;
        itemUnit[item.medicine.name] = _inferUnit(item.medicine.name);
      }
    }

    final sellers = itemRevenue.entries
        .map(
          (e) => TopSeller(
            name: e.key,
            quantity: itemQty[e.key] ?? 0,
            unit: itemUnit[e.key] ?? 'units',
            revenue: e.value,
          ),
        )
        .toList();

    sellers.sort((a, b) => b.revenue.compareTo(a.revenue));
    return sellers.take(5).toList();
  }

  List<CategorySales> _calculateCategorySales(List<OrderHistory> orders) {
    final categoryRevenue = <String, int>{};

    for (final order in orders) {
      for (final item in order.items) {
        final category = _inferCategory(item.medicine.name);
        final currentRevenue = categoryRevenue[category] ?? 0;
        categoryRevenue[category] =
            currentRevenue + item.totalCentavos;
      }
    }

    final total = categoryRevenue.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return [];

    // Largest-remainder method so percentages sum to exactly 100
    final exact = <String, double>{};
    for (final e in categoryRevenue.entries) {
      exact[e.key] = (e.value / total) * 100;
    }

    final floored = <String, int>{};
    for (final e in exact.entries) {
      floored[e.key] = e.value.floor();
    }

    var toDistribute = 100 - floored.values.fold(0, (a, b) => a + b);
    final sortedRemainders = exact.entries.toList()
      ..sort((a, b) => (b.value - b.value.floor()).compareTo(a.value - a.value.floor()));
    for (final e in sortedRemainders) {
      if (toDistribute <= 0) break;
      floored[e.key] = floored[e.key]! + 1;
      toDistribute--;
    }

    final categories = floored.entries
        .map(
          (e) => CategorySales(
            category: e.key,
            percentage: e.value,
            revenue: categoryRevenue[e.key]!,
          ),
        )
        .toList();

    categories.sort((a, b) => b.percentage.compareTo(a.percentage));
    return categories;
  }

  String _inferCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('vitamin') ||
        lower.contains('ascorbic') ||
        lower.contains('enervon')) {
      return 'Vitamins';
    }
    if (lower.contains('amox') ||
        lower.contains('cefalexin') ||
        lower.contains('cloxacillin') ||
        lower.contains('cef') ||
        lower.contains('cipro') ||
        lower.contains('antibiotic')) {
      return 'Antibiotics';
    }
    if (lower.contains('paracetamol') ||
        lower.contains('biogesic') ||
        lower.contains('mefenamic') ||
        lower.contains('ibuprofen') ||
        lower.contains('naproxen') ||
        lower.contains('pain')) {
      return 'Pain Relief';
    }
    if (lower.contains('cetirizine') ||
        lower.contains('allergy') ||
        lower.contains('loratadine')) {
      return 'Allergy';
    }
    if (lower.contains('losartan') ||
        lower.contains('amlodipine') ||
        lower.contains('metformin') ||
        lower.contains('blood') ||
        lower.contains('pressure') ||
        lower.contains('diabetes')) {
      return 'Chronic Care';
    }
    if (lower.contains('salbutamol') ||
        lower.contains('inhaler') ||
        lower.contains('asthma')) {
      return 'Respiratory';
    }
    if (lower.contains('loperamide') ||
        lower.contains('diata') ||
        lower.contains('diarrhea')) {
      return 'Digestive';
    }
    if (lower.contains('oil') ||
        lower.contains('cream') ||
        lower.contains('lotion') ||
        lower.contains('personal') ||
        lower.contains('baby')) {
      return 'Personal Care';
    }
    return 'General';
  }

  String _inferUnit(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('syrup') || lower.contains('suspension')) {
      return 'bottles';
    }
    if (lower.contains('inhaler') || lower.contains('nebule')) return 'pcs';
    if (lower.contains('inject') ||
        lower.contains('ampul') ||
        lower.contains('vial')) {
      return 'amps';
    }
    if (lower.contains('patch')) return 'patches';
    return 'units';
  }
}