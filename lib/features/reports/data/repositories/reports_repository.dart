import '../models/report_range.dart';
import '../models/sales_report.dart';
import '../models/stock_alert.dart';
import '../models/expiry_alert.dart';

abstract class ReportsRepository {
  /// Fetches the sales report for the given date range.
  Future<SalesReport> getSalesReport(ReportRange range);

  /// Fetches low stock alerts (items at or below reorder level).
  Future<List<StockAlert>> getLowStockAlerts();

  /// Fetches expiring items within the given number of days.
  /// Default is 90 days to match the HTML mockup.
  Future<List<ExpiryAlert>> getExpiryAlerts({int withinDays = 90});
}
