import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/reports/data/models/expiry_alert.dart';
import 'package:pharmaguide/features/reports/data/models/report_range.dart';
import 'package:pharmaguide/features/reports/data/models/sales_report.dart';
import 'package:pharmaguide/features/reports/data/models/stock_alert.dart';
import 'package:pharmaguide/features/reports/data/repositories/reports_repository.dart';
import 'package:pharmaguide/features/reports/presentation/providers/reports_provider.dart';

/// A fake [ReportsRepository] whose three methods can be configured to fail
/// independently. This lets us exercise granular error handling in
/// [ReportsProvider].
class FakeReportsRepository implements ReportsRepository {
  FakeReportsRepository({
    this.salesReport,
    this.lowStockAlerts = const [],
    this.expiryAlerts = const [],
    this.getSalesReportError,
    this.getLowStockAlertsError,
    this.getExpiryAlertsError,
  });

  SalesReport? salesReport;
  List<StockAlert> lowStockAlerts;
  List<ExpiryAlert> expiryAlerts;

  Object? getSalesReportError;
  Object? getLowStockAlertsError;
  Object? getExpiryAlertsError;

  @override
  Future<SalesReport> getSalesReport(ReportRange range) async {
    if (getSalesReportError != null) {
      throw getSalesReportError!;
    }
    return salesReport ?? _defaultSalesReport();
  }

  @override
  Future<List<StockAlert>> getLowStockAlerts() async {
    if (getLowStockAlertsError != null) {
      throw getLowStockAlertsError!;
    }
    return lowStockAlerts;
  }

  @override
  Future<List<ExpiryAlert>> getExpiryAlerts({int withinDays = 90}) async {
    if (getExpiryAlertsError != null) {
      throw getExpiryAlertsError!;
    }
    return expiryAlerts;
  }

  SalesReport _defaultSalesReport() => SalesReport(
        range: ReportRange.week,
        generatedAt: DateTime.now(),
        dailySales: const [],
        topSellers: const [],
        categorySales: const [],
        totalRevenue: 0,
        totalOrders: 0,
        totalItems: 0,
        profitMargin: 0.22,
      );
}

void main() {
  group('ReportsProvider granular state', () {
    late ReportsProvider provider;
    late FakeReportsRepository repo;

    setUp(() {
      repo = FakeReportsRepository();
      provider = ReportsProvider(repository: repo);
    });

    tearDown(() {
      provider.dispose();
    });

    test('initialize loads all three sources successfully', () async {
      await provider.initialize();

      expect(provider.salesReport, isNotNull);
      expect(provider.lowStockAlerts, isNotNull);
      expect(provider.expiryAlerts, isNotNull);
      expect(provider.salesError, isNull);
      expect(provider.stockError, isNull);
      expect(provider.expiryError, isNull);
      expect(provider.hasLoadedOnce, isTrue);
    });

    test('partial failure: stock fails, sales and expiry succeed', () async {
      repo = FakeReportsRepository(
        getLowStockAlertsError: 'network timeout',
        salesReport: SalesReport(
          range: ReportRange.week,
          generatedAt: DateTime.now(),
          dailySales: const [],
          topSellers: const [],
          categorySales: const [],
          totalRevenue: 10000,
          totalOrders: 5,
          totalItems: 10,
          profitMargin: 0.22,
        ),
      );
      provider = ReportsProvider(repository: repo);

      await provider.initialize();

      expect(provider.salesReport, isNotNull);
      expect(provider.salesError, isNull);
      expect(provider.stockError, contains('network timeout'));
      expect(provider.expiryError, isNull);
    });

    test('partial failure: expiry fails, sales and stock succeed', () async {
      repo = FakeReportsRepository(
        getExpiryAlertsError: 'permission denied',
        salesReport: SalesReport(
          range: ReportRange.week,
          generatedAt: DateTime.now(),
          dailySales: const [],
          topSellers: const [],
          categorySales: const [],
          totalRevenue: 10000,
          totalOrders: 5,
          totalItems: 10,
          profitMargin: 0.22,
        ),
      );
      provider = ReportsProvider(repository: repo);

      await provider.initialize();

      expect(provider.salesReport, isNotNull);
      expect(provider.expiryError, contains('permission denied'));
      expect(provider.stockError, isNull);
    });

    test('all three fail: all three errors are set', () async {
      repo = FakeReportsRepository(
        getSalesReportError: 'sales down',
        getLowStockAlertsError: 'stock down',
        getExpiryAlertsError: 'expiry down',
      );
      provider = ReportsProvider(repository: repo);

      await provider.initialize();

      expect(provider.salesError, contains('sales down'));
      expect(provider.stockError, contains('stock down'));
      expect(provider.expiryError, contains('expiry down'));
    });

    test('retry clears only the retried source error', () async {
      repo = FakeReportsRepository(
        getSalesReportError: 'sales down',
        getLowStockAlertsError: 'stock down',
        getExpiryAlertsError: 'expiry down',
      );
      provider = ReportsProvider(repository: repo);

      await provider.initialize();

      expect(provider.salesError, isNotNull);
      expect(provider.stockError, isNotNull);
      expect(provider.expiryError, isNotNull);

      // Fix the repo for sales only and retry sales
      repo.getSalesReportError = null;
      repo.salesReport = SalesReport(
        range: ReportRange.week,
        generatedAt: DateTime.now(),
        dailySales: const [],
        topSellers: const [],
        categorySales: const [],
        totalRevenue: 10000,
        totalOrders: 5,
        totalItems: 10,
        profitMargin: 0.22,
      );
      await provider.retry(ReportSource.sales);

      expect(provider.salesError, isNull);
      expect(provider.stockError, isNotNull);
      expect(provider.expiryError, isNotNull);
    });

    test('retry stock clears only stock error', () async {
      repo = FakeReportsRepository(
        getLowStockAlertsError: 'stock down',
      );
      provider = ReportsProvider(repository: repo);

      await provider.initialize();
      expect(provider.stockError, isNotNull);

      repo.getLowStockAlertsError = null;
      await provider.retry(ReportSource.stock);

      expect(provider.stockError, isNull);
    });

    test('retry expiry clears only expiry error', () async {
      repo = FakeReportsRepository(
        getExpiryAlertsError: 'expiry down',
      );
      provider = ReportsProvider(repository: repo);

      await provider.initialize();
      expect(provider.expiryError, isNotNull);

      repo.getExpiryAlertsError = null;
      await provider.retry(ReportSource.expiry);

      expect(provider.expiryError, isNull);
    });

    test('setRange clears only salesError and reloads sales', () async {
      repo = FakeReportsRepository(
        getSalesReportError: 'sales down',
        getLowStockAlertsError: 'stock down',
      );
      provider = ReportsProvider(repository: repo);

      await provider.initialize();
      expect(provider.salesError, isNotNull);
      expect(provider.stockError, isNotNull);

      repo.getSalesReportError = null;
      repo.salesReport = SalesReport(
        range: ReportRange.month,
        generatedAt: DateTime.now(),
        dailySales: const [],
        topSellers: const [],
        categorySales: const [],
        totalRevenue: 20000,
        totalOrders: 10,
        totalItems: 20,
        profitMargin: 0.22,
      );
      await provider.setRange(ReportRange.month);

      expect(provider.salesError, isNull);
      expect(provider.salesReport?.totalRevenue, 20000);
      expect(provider.range, ReportRange.month);
      // stock error should still be there
      expect(provider.stockError, isNotNull);
    });

    test('loading flags are set during load and cleared after', () async {
      repo = FakeReportsRepository(
        salesReport: SalesReport(
          range: ReportRange.week,
          generatedAt: DateTime.now(),
          dailySales: const [],
          topSellers: const [],
          categorySales: const [],
          totalRevenue: 10000,
          totalOrders: 5,
          totalItems: 10,
          profitMargin: 0.22,
        ),
      );
      provider = ReportsProvider(repository: repo);

      expect(provider.isSalesLoading, isFalse);
      expect(provider.isStockLoading, isFalse);
      expect(provider.isExpiryLoading, isFalse);

      // Start loading
      final loadFuture = provider.initialize();

      // We can't easily check mid-load without async timing, so just verify
      // final state
      await loadFuture;

      expect(provider.isSalesLoading, isFalse);
      expect(provider.isStockLoading, isFalse);
      expect(provider.isExpiryLoading, isFalse);
    });

    test('retryAll reloads all sources', () async {
      repo = FakeReportsRepository(
        getSalesReportError: 'sales down',
        getLowStockAlertsError: 'stock down',
        getExpiryAlertsError: 'expiry down',
      );
      provider = ReportsProvider(repository: repo);

      await provider.initialize();
      expect(provider.salesError, isNotNull);
      expect(provider.stockError, isNotNull);
      expect(provider.expiryError, isNotNull);

      repo.getSalesReportError = null;
      repo.getLowStockAlertsError = null;
      repo.getExpiryAlertsError = null;
      await provider.retryAll();

      expect(provider.salesError, isNull);
      expect(provider.stockError, isNull);
      expect(provider.expiryError, isNull);
    });
  });
}