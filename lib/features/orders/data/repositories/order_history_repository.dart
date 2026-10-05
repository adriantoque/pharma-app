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

/// Builds the [OrderHistoryRepository] that belongs to a user.
///
/// Which repository that is depends on the user: a signed-in pharmacist's
/// history lives in Firestore, while offline there is nowhere to put a finished
/// order so it is kept in memory for the session. Naming the rule once means the
/// dashboard and the Orders tab cannot disagree about where history lives.
typedef OrderHistoryRepositoryFactory =
    OrderHistoryRepository Function(String uid);
