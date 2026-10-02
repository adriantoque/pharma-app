import 'dart:async';
import 'dart:math' as math;

import '../../../search/presentation/providers/medicine_provider.dart';
import '../../../search/data/models/medicine_model.dart';
import '../models/report_range.dart';
import '../models/sales_report.dart';
import '../models/stock_alert.dart';
import '../models/expiry_alert.dart';
import 'reports_repository.dart';

/// Implementation of [ReportsRepository] using existing providers.
class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl({required MedicineProvider medicineProvider})
    : _medicineProvider = medicineProvider;

  final MedicineProvider _medicineProvider;

  static const double _defaultProfitMargin = 0.22; // 22% from HTML mockup

  @override
  Future<SalesReport> getSalesReport(ReportRange range) async {
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day);
    final startDate = endDate.subtract(Duration(days: range.days - 1));

    // Get completed orders from OrderProvider
    // Note: OrderProvider currently only tracks active order.
    // For now, we'll generate realistic sample data based on inventory.
    // In a real implementation, this would query completed orders from storage.
    final completedOrders = _generateSampleOrders(startDate, endDate, range);

    final dailySales = _aggregateDailySales(
      completedOrders,
      startDate,
      endDate,
    );
    final topSellers = _calculateTopSellers(completedOrders);
    final categorySales = _calculateCategorySales(completedOrders);

    final totalRevenue = completedOrders.fold(0, (sum, o) => sum + o.total);
    final totalOrders = completedOrders.length;
    final totalItems = completedOrders.fold(0, (sum, o) => sum + o.itemCount);

    return SalesReport(
      range: range,
      generatedAt: DateTime.now(),
      dailySales: dailySales,
      topSellers: topSellers,
      categorySales: categorySales,
      totalRevenue: totalRevenue,
      totalOrders: totalOrders,
      totalItems: totalItems,
      profitMargin: _defaultProfitMargin,
    );
  }

  @override
  Future<List<StockAlert>> getLowStockAlerts() async {
    final medicines = _medicineProvider.all();
    final alerts = <StockAlert>[];

    for (final med in medicines) {
      if (med.isLowStock || med.isOutOfStock) {
        final reorderLevel = med.isOutOfStock
            ? 10
            : MedicineModel.lowStockThreshold + 5;
        alerts.add(
          StockAlert(
            name: med.name,
            currentStock: med.stock ?? 0,
            reorderLevel: reorderLevel,
            category: _inferCategory(med.name),
          ),
        );
      }
    }

    // Sort: out of stock first, then by lowest stock
    alerts.sort((a, b) {
      if (a.currentStock == 0 && b.currentStock != 0) return -1;
      if (a.currentStock != 0 && b.currentStock == 0) return 1;
      return a.currentStock.compareTo(b.currentStock);
    });

    return alerts;
  }

  @override
  Future<List<ExpiryAlert>> getExpiryAlerts({int withinDays = 90}) async {
    final medicines = _medicineProvider.all();
    final alerts = <ExpiryAlert>[];

    for (final med in medicines) {
      if (med.expiryDate != null) {
        final daysUntil = med.daysUntilExpiry;
        if (daysUntil != null && daysUntil <= withinDays) {
          alerts.add(
            ExpiryAlert(
              name: med.name,
              expiryDate: med.expiryDate!,
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

  /// Generates sample completed orders for the date range.
  /// In a real app, this would query a sales/orders database.
  List<_CompletedOrder> _generateSampleOrders(
    DateTime startDate,
    DateTime endDate,
    ReportRange range,
  ) {
    final medicines = _medicineProvider
        .all()
        .where((m) => m.stock != null && m.stock! > 0)
        .toList();
    final orders = <_CompletedOrder>[];

    // Use a seeded random for consistent results
    final random = math.Random(42);
    final daysInRange = range.days;

    for (int dayOffset = 0; dayOffset < daysInRange; dayOffset++) {
      final date = startDate.add(Duration(days: dayOffset));
      final isWeekend = date.weekday >= 6;
      final baseOrders = isWeekend ? 8 : 12;
      final variance = random.nextInt(6) - 3; // -3 to +2
      final ordersToday = (baseOrders + variance).clamp(3, 20);

      for (int i = 0; i < ordersToday; i++) {
        final itemCount = 1 + random.nextInt(5); // 1-5 items per order
        final selectedMeds = medicines
            .where((m) => random.nextDouble() < 0.3)
            .take(itemCount)
            .toList();

        if (selectedMeds.isEmpty) continue;

        int orderTotal = 0;
        int orderItems = 0;
        for (final med in selectedMeds) {
          final qty = 1 + random.nextInt(3); // 1-3 per item
          orderTotal += med.priceCentavos * qty;
          orderItems += qty;
        }

        orders.add(
          _CompletedOrder(
            date: date,
            items: selectedMeds
                .map((m) => _OrderItem(m, 1 + random.nextInt(3)))
                .toList(),
            total: orderTotal,
            itemCount: orderItems,
          ),
        );
      }
    }

    return orders;
  }

  List<DailySales> _aggregateDailySales(
    List<_CompletedOrder> orders,
    DateTime startDate,
    DateTime endDate,
  ) {
    final dailyMap = <DateTime, int>{};

    for (final order in orders) {
      final dayKey = DateTime(
        order.date.year,
        order.date.month,
        order.date.day,
      );
      dailyMap[dayKey] = (dailyMap[dayKey] ?? 0) + order.total;
    }

    final dailySales = <DailySales>[];
    var current = startDate;
    while (!current.isAfter(endDate)) {
      dailySales.add(DailySales(date: current, amount: dailyMap[current] ?? 0));
      current = current.add(const Duration(days: 1));
    }

    return dailySales;
  }

  List<TopSeller> _calculateTopSellers(List<_CompletedOrder> orders) {
    final itemRevenue = <String, int>{};
    final itemQty = <String, int>{};
    final itemUnit = <String, String>{};

    for (final order in orders) {
      for (final item in order.items) {
        final currentRevenue = itemRevenue[item.medicine.name] ?? 0;
        itemRevenue[item.medicine.name] =
            currentRevenue + item.medicine.priceCentavos * item.quantity;
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

  List<CategorySales> _calculateCategorySales(List<_CompletedOrder> orders) {
    final categoryRevenue = <String, int>{};

    for (final order in orders) {
      for (final item in order.items) {
        final category = _inferCategory(item.medicine.name);
        final currentRevenue = categoryRevenue[category] ?? 0;
        categoryRevenue[category] =
            currentRevenue + item.medicine.priceCentavos * item.quantity;
      }
    }

    final total = categoryRevenue.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return [];

    final categories = categoryRevenue.entries
        .map(
          (e) => CategorySales(
            category: e.key,
            percentage: ((e.value / total) * 100).round(),
            revenue: e.value,
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
    if (lower.contains('syrup') || lower.contains('suspension'))
      return 'bottles';
    if (lower.contains('inhaler') || lower.contains('nebule')) return 'pcs';
    if (lower.contains('inject') ||
        lower.contains('ampul') ||
        lower.contains('vial'))
      return 'amps';
    if (lower.contains('patch')) return 'patches';
    return 'units';
  }
}

/// Internal: represents a completed order for reporting.
class _CompletedOrder {
  const _CompletedOrder({
    required this.date,
    required this.items,
    required this.total,
    required this.itemCount,
  });

  final DateTime date;
  final List<_OrderItem> items;
  final int total;
  final int itemCount;
}

/// Internal: one line in a completed order.
class _OrderItem {
  const _OrderItem(this.medicine, this.quantity);

  final MedicineModel medicine;
  final int quantity;
}
