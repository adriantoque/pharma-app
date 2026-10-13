import 'dart:async';

import 'package:pharmaguide/features/orders/data/models/order_history_model.dart';
import 'package:pharmaguide/features/orders/data/repositories/order_history_repository.dart';

/// An in-memory [OrderHistoryRepository] for widget tests.
///
/// Behaves the way the screens depend on: it emits the whole (newest-first)
/// history on subscribe, and again after every change, so a screen reading it
/// through a `StreamBuilder` or a provider reacts to an approval or rejection
/// exactly as it would to a real backend.
class FakeOrderHistoryRepository implements OrderHistoryRepository {
  FakeOrderHistoryRepository([List<OrderHistory> orders = const []])
      : _orders = [...orders];

  List<OrderHistory> _orders;

  final StreamController<List<OrderHistory>> _controller =
      StreamController<List<OrderHistory>>.broadcast();

  /// When set, [watchAll] fails with this instead of emitting, as a Firestore
  /// query does when the device cannot reach the network.
  Object? readError;

  /// The stored history, newest first, for asserting on the write side.
  List<OrderHistory> get orders => _sorted;

  List<OrderHistory> get _sorted {
    final all = [..._orders]..sort((a, b) => b.time.compareTo(a.time));
    return List<OrderHistory>.unmodifiable(all);
  }

  @override
  Stream<List<OrderHistory>> watchAll() async* {
    if (readError != null) throw readError!;
    yield _sorted;
    yield* _controller.stream;
  }

  @override
  Future<void> save(OrderHistory order) async {
    _orders = [
      for (final existing in _orders)
        if (existing.id != order.id) existing,
      order,
    ];
    _emit();
  }

  @override
  Future<void> updateStatus(String id, OrderStatus status) async {
    _orders = [
      for (final order in _orders)
        if (order.id == id) order.copyWith(status: status) else order,
    ];
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _orders = _orders.where((order) => order.id != id).toList();
    _emit();
  }

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(_sorted);
  }

  void dispose() {
    if (!_controller.isClosed) unawaited(_controller.close());
  }
}
