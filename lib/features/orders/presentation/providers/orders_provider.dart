import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/order_history_model.dart';
import '../../data/repositories/order_history_repository.dart';

/// Provider for the Orders screen state.
class OrdersProvider extends ChangeNotifier {
  OrdersProvider({required this.historyFactory})
    : _currentTab = OrderTab.all,
      _orders = const [],
      _isLoading = false,
      _error = null;

  /// How the screen builds the repository it reads orders from.
  ///
  /// Public so the parameter and the field can be the same name: a private
  /// field behind a public parameter cannot be an initializing formal, and
  /// renaming the parameter to suit the field would leak the underscore to
  /// every call site.
  final OrderHistoryRepository Function() historyFactory;

  OrderHistoryRepository get _history => historyFactory();

  OrderTab _currentTab = OrderTab.all;
  List<OrderHistory> _orders = const [];
  bool _isLoading = false;
  String? _error;

  OrderTab get currentTab => _currentTab;
  List<OrderHistory> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// The tab enumeration for the three report views.
  static const List<OrderTab> tabs = [
    OrderTab.all,
    OrderTab.new_,
    OrderTab.approved,
  ];

  /// Initializes the provider by loading all orders.
  Future<void> initialize() async {
    await _loadOrders();
  }

  /// Changes the active tab.
  void setTab(OrderTab tab) {
    if (_currentTab == tab) return;
    _currentTab = tab;
    notifyListeners();
  }

  /// Approves an order (changes status from new to approved).
  Future<void> approveOrder(String id) async {
    try {
      await _history.updateStatus(id, OrderStatus.approved);
      await _loadOrders();
    } catch (e) {
      _error = 'Failed to approve order: $e';
      notifyListeners();
    }
  }

  Future<void> _loadOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _history.watchAll().first;
      _orders = snapshot;
    } catch (e) {
      _error = 'Failed to load orders: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

/// Tab enumeration for the three order views.
enum OrderTab {
  all('All'),
  new_('New'),
  approved('Approved');

  const OrderTab(this.label);

  final String label;
}
