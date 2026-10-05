import 'package:flutter/material.dart';

import '../../data/models/report_range.dart';
import '../../data/models/sales_report.dart';
import '../../data/models/stock_alert.dart';
import '../../data/models/expiry_alert.dart';
import '../../data/repositories/reports_repository.dart';

/// Source enumeration for granular error/loading tracking.
enum ReportSource {
  sales('Sales'),
  stock('Low Stock'),
  expiry('Expiring');

  const ReportSource(this.label);

  final String label;
}

/// Provider for the Reports screen state.
class ReportsProvider extends ChangeNotifier {
  ReportsProvider({required this.repository})
      : _range = ReportRange.week,
        _currentTab = ReportTab.sales;

  /// Where the figures come from.
  ///
  /// Public so the parameter and the field can be the same name; a private
  /// field behind a public parameter cannot be an initializing formal.
  final ReportsRepository repository;

  ReportRange _range = ReportRange.week;
  ReportTab _currentTab = ReportTab.sales;

  SalesReport? _salesReport;
  List<StockAlert> _lowStockAlerts = [];
  List<ExpiryAlert> _expiryAlerts = [];

  bool _isSalesLoading = false;
  bool _isStockLoading = false;
  bool _isExpiryLoading = false;
  bool _hasLoadedOnce = false;

  String? _salesError;
  String? _stockError;
  String? _expiryError;

  // Getters
  ReportRange get range => _range;
  ReportTab get currentTab => _currentTab;
  SalesReport? get salesReport => _salesReport;
  List<StockAlert> get lowStockAlerts => _lowStockAlerts;
  List<ExpiryAlert> get expiryAlerts => _expiryAlerts;

  bool get isSalesLoading => _isSalesLoading;
  bool get isStockLoading => _isStockLoading;
  bool get isExpiryLoading => _isExpiryLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  bool get isLoading => _isSalesLoading || _isStockLoading || _isExpiryLoading;

  String? get salesError => _salesError;
  String? get stockError => _stockError;
  String? get expiryError => _expiryError;

  /// The tab enumeration for the three report views.
  static const List<ReportTab> tabs = [
    ReportTab.sales,
    ReportTab.lowStock,
    ReportTab.expiry,
  ];

  /// Initializes the provider by loading all data.
  Future<void> initialize() async {
    await _loadAll();
  }

  /// Changes the date range and reloads sales data.
  Future<void> setRange(ReportRange range) async {
    if (_range == range) return;
    _range = range;
    notifyListeners();
    await _run(ReportSource.sales, _loadSalesReport);
  }

  /// Changes the active tab.
  void setTab(ReportTab tab) {
    if (_currentTab == tab) return;
    _currentTab = tab;
    notifyListeners();
  }

  /// Retries loading a specific source after an error.
  Future<void> retry(ReportSource source) async {
    switch (source) {
      case ReportSource.sales:
        await _run(ReportSource.sales, _loadSalesReport);
      case ReportSource.stock:
        await _run(ReportSource.stock, _loadLowStockAlerts);
      case ReportSource.expiry:
        await _run(ReportSource.expiry, _loadExpiryAlerts);
    }
  }

  /// Retries loading all sources after a complete failure.
  Future<void> retryAll() async {
    await _loadAll();
  }

  Future<void> _loadAll() async {
    _isSalesLoading = true;
    _isStockLoading = true;
    _isExpiryLoading = true;
    _salesError = null;
    _stockError = null;
    _expiryError = null;
    notifyListeners();

    await Future.wait([
      _run(ReportSource.sales, _loadSalesReport),
      _run(ReportSource.stock, _loadLowStockAlerts),
      _run(ReportSource.expiry, _loadExpiryAlerts),
    ]);

    _hasLoadedOnce = true;
    notifyListeners();
  }

  Future<void> _run(ReportSource source, Future<void> Function() loader) async {
    _setLoading(source, true);
    _clearError(source);
    try {
      await loader();
    } catch (e) {
      _handleError(source, e);
    } finally {
      _setLoading(source, false);
    }
  }

  void _setLoading(ReportSource source, bool value) {
    switch (source) {
      case ReportSource.sales:
        _isSalesLoading = value;
      case ReportSource.stock:
        _isStockLoading = value;
      case ReportSource.expiry:
        _isExpiryLoading = value;
    }
    notifyListeners();
  }

  void _clearError(ReportSource source) {
    switch (source) {
      case ReportSource.sales:
        _salesError = null;
      case ReportSource.stock:
        _stockError = null;
      case ReportSource.expiry:
        _expiryError = null;
    }
  }

  void _handleError(ReportSource source, Object e) {
    final message = 'Error loading ${source.label.toLowerCase()} reports: $e';
    switch (source) {
      case ReportSource.sales:
        _salesError = message;
      case ReportSource.stock:
        _stockError = message;
      case ReportSource.expiry:
        _expiryError = message;
    }
    notifyListeners();
  }

  Future<void> _loadSalesReport() async {
    _salesReport = await repository.getSalesReport(_range);
  }

  Future<void> _loadLowStockAlerts() async {
    _lowStockAlerts = await repository.getLowStockAlerts();
  }

  Future<void> _loadExpiryAlerts() async {
    _expiryAlerts = await repository.getExpiryAlerts();
  }
}

/// Report tab enumeration.
enum ReportTab {
  sales('Sales'),
  lowStock('Low stock'),
  expiry('Expiring');

  const ReportTab(this.label);

  final String label;

  static ReportTab fromLabel(String label) {
    return switch (label) {
      'Sales' => ReportTab.sales,
      'Low stock' => ReportTab.lowStock,
      'Expiring' => ReportTab.expiry,
      _ => ReportTab.sales,
    };
  }
}