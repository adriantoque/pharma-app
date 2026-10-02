import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/report_range.dart';
import '../../data/models/sales_report.dart';
import '../../data/models/stock_alert.dart';
import '../../data/models/expiry_alert.dart';
import '../../data/repositories/reports_repository.dart';

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

  bool _isLoading = false;
  String? _error;

  // Getters
  ReportRange get range => _range;
  ReportTab get currentTab => _currentTab;
  SalesReport? get salesReport => _salesReport;
  List<StockAlert> get lowStockAlerts => _lowStockAlerts;
  List<ExpiryAlert> get expiryAlerts => _expiryAlerts;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
    await _loadSalesReport();
  }

  /// Changes the active tab.
  void setTab(ReportTab tab) {
    if (_currentTab == tab) return;
    _currentTab = tab;
    notifyListeners();
  }

  /// Retries loading after an error.
  Future<void> retry() async {
    await _loadAll();
  }

  Future<void> _loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadSalesReport(),
        _loadLowStockAlerts(),
        _loadExpiryAlerts(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSalesReport() async {
    try {
      _salesReport = await repository.getSalesReport(_range);
    } catch (e) {
      _error = 'Failed to load sales report: $e';
    }
  }

  Future<void> _loadLowStockAlerts() async {
    try {
      _lowStockAlerts = await repository.getLowStockAlerts();
    } catch (e) {
      _error = 'Failed to load low stock alerts: $e';
    }
  }

  Future<void> _loadExpiryAlerts() async {
    try {
      _expiryAlerts = await repository.getExpiryAlerts();
    } catch (e) {
      _error = 'Failed to load expiry alerts: $e';
    }
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
