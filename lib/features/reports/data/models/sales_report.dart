import 'dart:math';

import 'report_range.dart';

/// Daily sales data point for charting.
class DailySales {
  const DailySales({required this.date, required this.amount});

  final DateTime date;
  final int amount; // in centavos

  String get formattedAmount => '₱${(amount / 100).toStringAsFixed(2)}';
}

/// Top selling item.
class TopSeller {
  const TopSeller({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.revenue,
  });

  final String name;
  final int quantity;
  final String unit;
  final int revenue; // in centavos

  String get formattedRevenue => '₱${(revenue / 100).toStringAsFixed(2)}';
}

/// Sales by category.
class CategorySales {
  const CategorySales({
    required this.category,
    required this.percentage,
    required this.revenue,
  });

  final String category;
  final int percentage; // 0-100
  final int revenue; // in centavos

  String get formattedRevenue => '₱${(revenue / 100).toStringAsFixed(2)}';
}

/// Complete sales report for a given range.
class SalesReport {
  const SalesReport({
    required this.range,
    required this.generatedAt,
    required this.dailySales,
    required this.topSellers,
    required this.categorySales,
    required this.totalRevenue,
    required this.totalOrders,
    required this.totalItems,
    required this.profitMargin,
  });

  final ReportRange range;
  final DateTime generatedAt;
  final List<DailySales> dailySales;
  final List<TopSeller> topSellers;
  final List<CategorySales> categorySales;
  final int totalRevenue; // in centavos
  final int totalOrders;
  final int totalItems;
  final double profitMargin; // e.g., 0.22 for 22%

  /// Total revenue formatted as peso string.
  String get formattedTotalRevenue {
    final pesos = totalRevenue / 100;
    return '₱${pesos.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
  }

  /// Total profit formatted as peso string.
  String get formattedProfit {
    final profit = (totalRevenue * profitMargin).round();
    final pesos = profit / 100;
    return '₱${pesos.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
  }

  /// Average bill value.
  String get formattedAverageBill {
    if (totalOrders == 0) return '₱0.00';
    final avg = (totalRevenue / totalOrders).round();
    final pesos = avg / 100;
    return '₱${pesos.toStringAsFixed(2)}';
  }

  /// Total customers served (same as total orders for now).
  int get totalCustomers => totalOrders;

  /// Returns daily sales data for the chart, scaled to the range.
  List<DailySales> get chartData {
    if (range == ReportRange.today) {
      // Show last 7 days for context
      return dailySales.length > 7
          ? dailySales.sublist(dailySales.length - 7)
          : dailySales;
    }
    return dailySales.sublist(max(0, dailySales.length - range.days));
  }

  /// Maximum daily revenue in the chart data (for scaling).
  int get maxDailyRevenue {
    if (chartData.isEmpty) return 1;
    return chartData.map((d) => d.amount).reduce(max);
  }
}
