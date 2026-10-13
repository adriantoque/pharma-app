import 'package:flutter/foundation.dart';

import '../../data/models/order_history_model.dart';
import '../../data/repositories/order_history_repository.dart';

/// The Orders screen's write path.
///
/// Reading the orders is the screen's own business -- it subscribes to the
/// repository's stream directly, so it stays live without a load step. What
/// lives here is only the decision: approving or rejecting an order goes
/// through one method so the two buttons cannot drift apart in how they report
/// a failure.
class OrdersProvider extends ChangeNotifier {
  OrdersProvider({required this.historyFactory});

  /// How the screen builds the repository it writes orders to.
  ///
  /// Public so the parameter and the field can be the same name: a private
  /// field behind a public parameter cannot be an initializing formal, and
  /// renaming the parameter to suit the field would leak the underscore to
  /// every call site.
  final OrderHistoryRepository Function() historyFactory;

  OrderHistoryRepository get _history => historyFactory();

  /// Moves an order to [status].
  ///
  /// The repository emits the change on the stream the screen already listens
  /// to, so the list updates itself and no reload is needed here. A failure is
  /// logged rather than surfaced: the screen has no place to show it, and the
  /// order simply stays pending for the next attempt.
  Future<void> updateOrderStatus(String id, OrderStatus status) async {
    try {
      await _history.updateStatus(id, status);
    } catch (e) {
      debugPrint('Failed to update order $id: $e');
    }
  }
}
