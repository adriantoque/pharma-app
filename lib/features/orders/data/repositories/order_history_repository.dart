import 'dart:async';

import '../models/order_history_model.dart';

/// Repository for order history.
abstract class OrderHistoryRepository {
  /// Stream of all orders, ordered by time descending (newest first).
  Stream<List<OrderHistory>> watchAll();

  /// Saves a new order to history.
  Future<void> save(OrderHistory order);

  /// Updates the status of an existing order.
  Future<void> updateStatus(String id, OrderStatus status);

  /// Deletes an order from history.
  Future<void> delete(String id);
}
