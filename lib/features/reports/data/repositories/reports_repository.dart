import '../../../admin/data/models/store_settings_model.dart';
import '../../data/models/report_range.dart';
import '../../data/models/sales_report.dart';
import '../../data/models/stock_alert.dart';
import '../../data/models/expiry_alert.dart';

abstract class ReportsRepository {
  /// Fetches the sales report for the given date range.
  Future<SalesReport> getSalesReport(ReportRange range);

  /// Fetches low stock alerts (items at or below reorder level).
  ///
  /// [coverageDays] is the demand window each reorder target covers. It comes
  /// from Store settings (`reorderCoverageDays`) and defaults to that
  /// setting's compiled-in default, so a caller with no settings yet gets the
  /// same targets the settings screen advertises as the default.
  Future<List<StockAlert>> getLowStockAlerts({
    int coverageDays = StoreSettingsModel.defaultReorderCoverageDays,
  });

  /// Fetches expiring items within the given number of days.
  /// Default is 90 days to match the HTML mockup.
  Future<List<ExpiryAlert>> getExpiryAlerts({int withinDays = 90});
}
