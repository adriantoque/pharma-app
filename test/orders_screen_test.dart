import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/orders/data/models/order_history_model.dart';
import 'package:pharmaguide/features/orders/data/models/order_line_model.dart';
import 'package:pharmaguide/features/orders/data/repositories/order_history_repository.dart';
import 'package:pharmaguide/features/orders/presentation/providers/orders_provider.dart';
import 'package:pharmaguide/features/orders/presentation/screens/orders_screen.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:provider/provider.dart';

/// A fake [OrderHistoryRepository] for widget tests.
///
/// Holds a mutable list of orders and re-emits on every change, so the screen
/// reacts to [updateStatus] the way it would to a real backend.
class FakeOrderHistoryRepository implements OrderHistoryRepository {
  FakeOrderHistoryRepository(List<OrderHistory> orders) : _orders = orders;

  List<OrderHistory> _orders;
  final StreamController<List<OrderHistory>> _controller =
      StreamController<List<OrderHistory>>.broadcast();

  @override
  Stream<List<OrderHistory>> watchAll() async* {
    yield List<OrderHistory>.unmodifiable(_orders);
    yield* _controller.stream;
  }

  @override
  Future<void> save(OrderHistory order) async {
    _orders = [..._orders, order];
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
    _controller.add(List<OrderHistory>.unmodifiable(_orders));
  }
}

void main() {
  const phoneSize = Size(360, 720);

  const alcohol = MedicineModel(
    name: 'Alcohol',
    priceCentavos: 6500,
    stock: 200,
  );
  const cefalexin = MedicineModel(
    name: 'cefalexin',
    priceCentavos: 4500,
    stock: 200,
  );

  OrderHistory order({
    required String id,
    required DateTime time,
    OrderStatus status = OrderStatus.new_,
    List<OrderLineModel> items = const [],
  }) {
    return OrderHistory(
      id: id,
      time: time,
      status: status,
      items: items,
      totalCentavos: items.fold(0, (sum, line) => sum + line.totalCentavos),
    );
  }

  final newOrder = order(
    id: '1',
    time: DateTime(2025, 8, 3, 10, 30),
    status: OrderStatus.new_,
    items: [
      OrderLineModel(medicine: alcohol, quantity: 2),
      OrderLineModel(medicine: cefalexin, quantity: 1),
    ],
  );

  final approvedOrder = order(
    id: '2',
    time: DateTime(2025, 8, 2, 9, 15),
    status: OrderStatus.approved,
    items: [OrderLineModel(medicine: cefalexin, quantity: 3)],
  );

  /// Pumps the Orders screen with an [OrdersProvider] above it, as `main.dart`
  /// does, so the card's Approve/Reject taps resolve.
  Future<void> pumpOrders(
    WidgetTester tester,
    FakeOrderHistoryRepository repository,
  ) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = OrdersProvider(historyFactory: () => repository);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<OrdersProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: OrdersScreen(historyFactory: () => repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expandFirstOrder(WidgetTester tester) async {
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
  }

  group('pending list', () {
    testWidgets('shows only the orders awaiting a decision', (tester) async {
      final repo = FakeOrderHistoryRepository([newOrder, approvedOrder]);

      await pumpOrders(tester, repo);

      expect(find.text('Order #1'), findsOneWidget);
      expect(find.text('Order #2'), findsNothing);
    });

    testWidgets('shows an empty message when there are no orders', (
      tester,
    ) async {
      final repo = FakeOrderHistoryRepository([]);

      await pumpOrders(tester, repo);

      expect(find.text('No pending orders'), findsOneWidget);
      expect(
        find.text('New orders waiting for approval will appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('shows an empty message when none are pending', (tester) async {
      final repo = FakeOrderHistoryRepository([approvedOrder]);

      await pumpOrders(tester, repo);

      expect(find.text('No pending orders'), findsOneWidget);
    });
  });

  group('order card rendering', () {
    testWidgets('shows the order id, item count and total', (tester) async {
      final repo = FakeOrderHistoryRepository([newOrder]);

      await pumpOrders(tester, repo);

      expect(find.text('Order #1'), findsOneWidget);
      expect(find.textContaining('2 item(s)'), findsOneWidget);
      // 6500 * 2 + 4500 * 1 = 17500 centavos.
      expect(find.text('₱175.00'), findsOneWidget);
    });

    testWidgets('expanding reveals the line items and the decision buttons', (
      tester,
    ) async {
      final repo = FakeOrderHistoryRepository([newOrder]);

      await pumpOrders(tester, repo);
      await expandFirstOrder(tester);

      expect(find.text('Order Line Items'), findsOneWidget);
      expect(find.text('2x Alcohol'), findsOneWidget);
      expect(find.text('1x cefalexin'), findsOneWidget);
      // Per-line totals: 6500 * 2 = 13000 and 4500 * 1 = 4500 centavos.
      expect(find.text('₱130.00'), findsOneWidget);
      expect(find.text('₱45.00'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });
  });

  group('decision', () {
    testWidgets('approving clears the order from the pending list', (
      tester,
    ) async {
      final repo = FakeOrderHistoryRepository([newOrder]);

      await pumpOrders(tester, repo);
      await expandFirstOrder(tester);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('Order #1'), findsNothing);
      expect(find.text('No pending orders'), findsOneWidget);
    });

    testWidgets('rejecting clears the order from the pending list', (
      tester,
    ) async {
      final repo = FakeOrderHistoryRepository([newOrder]);

      await pumpOrders(tester, repo);
      await expandFirstOrder(tester);

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(find.text('Order #1'), findsNothing);
      expect(find.text('No pending orders'), findsOneWidget);
    });
  });
}
