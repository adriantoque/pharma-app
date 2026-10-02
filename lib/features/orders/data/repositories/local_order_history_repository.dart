import 'dart:async';

import '../../../../core/lifecycle/disposable_store.dart';
import '../models/order_history_model.dart';
import 'order_history_repository.dart';

/// Order history that lives only as long as the process, for offline mode.
///
/// Offline there is no server to write to and nothing to read back, but "no
/// repository" is the wrong answer to that: [OrderProvider.complete] refuses to
/// finish an order it has nowhere to record, so a counter tablet with no
/// connection would refuse to sell anything at all. Keeping the day's sales in
/// memory costs nothing and means offline is a smaller app rather than a
/// broken one.
///
/// What it deliberately does not do is persist. Unlike the draft basket -- which
/// is a sale in progress, worth a customer standing at the counter -- finished
/// orders are already gone by the time the process is, and the count a tablet
/// shows at closing time is the count the pharmacist has on their receipt. So the
/// history empties on restart, and the next day's screen starts empty rather than
/// lying about what was sold.
///
/// Held in [Map] keyed by id, so a repeated [save] of the same order replaces it
/// rather than appending a second copy of the same sale.
class LocalOrderHistoryRepository
    implements OrderHistoryRepository, DisposableStore {
  final Map<String, OrderHistory> _orders = {};
  final StreamController<List<OrderHistory>> _controller =
      StreamController<List<OrderHistory>>.broadcast();

  bool _disposed = false;

  /// The current history, newest first, which is the order [watchAll] promises.
  ///
  /// Sorted on the way out rather than on the way in, because a history that is
  /// only kept sorted correctly for orders added at the end will show an older
  /// sale above a newer one as soon as an order's status is changed.
  List<OrderHistory> get _sorted {
    final all = _orders.values.toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    return List<OrderHistory>.unmodifiable(all);
  }

  @override
  Stream<List<OrderHistory>> watchAll() async* {
    yield _sorted;
    yield* _controller.stream;
  }

  @override
  Future<void> save(OrderHistory order) async {
    _orders[order.id] = order;
    _emit();
  }

  @override
  Future<void> updateStatus(String id, OrderStatus status) async {
    final order = _orders[id];
    if (order == null) return;
    _orders[id] = order.copyWith(status: status);
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    if (_orders.remove(id) == null) return;
    _emit();
  }

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(_sorted);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_controller.close());
  }
}
