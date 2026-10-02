import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/orders/data/models/order_history_model.dart';
import 'package:pharmaguide/features/orders/data/models/order_line_model.dart';
import 'package:pharmaguide/features/orders/data/repositories/order_history_repository.dart';
import 'package:pharmaguide/features/orders/presentation/screens/orders_screen.dart';
import 'package:pharmaguide/features/orders/presentation/widgets/order_card.dart';
import 'package:pharmaguide/features/orders/presentation/widgets/order_tabs.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';

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

  /// Finds a tab label scoped to the tab bar, so it never collides with the
  /// status badge text on an order card.
  Finder tab(String label) => find.descendant(
    of: find.byType(OrderTabs),
    matching: find.text(label),
  );

  /// Finds text scoped to an order card, so it never collides with the tab
  /// bar labels.
  Finder card(String text) => find.descendant(
    of: find.byType(OrderCard),
    matching: find.text(text),
  );

  Future<void> pumpOrders(
    WidgetTester tester,
    FakeOrderHistoryRepository repository,
  ) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: OrdersScreen(historyFactory: () => repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('tab filtering', () {
    testWidgets('shows all orders on the All tab', (tester) async {
      final repo = FakeOrderHistoryRepository([newOrder, approvedOrder]);

      await pumpOrders(tester, repo);

      expect(find.text('Order #1'), findsOneWidget);
      expect(find.text('Order #2'), findsOneWidget);
      expect(tab('All'), findsOneWidget);
      expect(tab('New'), findsOneWidget);
      expect(tab('Approved'), findsOneWidget);
    });

    testWidgets('the New tab shows only new orders', (tester) async {
      final repo = FakeOrderHistoryRepository([newOrder, approvedOrder]);

      await pumpOrders(tester, repo);

      await tester.tap(tab('New'));
      await tester.pumpAndSettle();

      expect(find.text('Order #1'), findsOneWidget);
      expect(find.text('Order #2'), findsNothing);
    });

    testWidgets('the Approved tab shows only approved orders', (tester) async {
      final repo = FakeOrderHistoryRepository([newOrder, approvedOrder]);

      await pumpOrders(tester, repo);

      await tester.tap(tab('Approved'));
      await tester.pumpAndSettle();

      expect(find.text('Order #1'), findsNothing);
      expect(find.text('Order #2'), findsOneWidget);
    });

    testWidgets('tab counts reflect the number of orders', (tester) async {
      final repo = FakeOrderHistoryRepository([newOrder, approvedOrder]);

      await pumpOrders(tester, repo);

      // Counts live in the tab bar, so they are read from there rather than from
      // the whole tree, where an order line could show the same digit.
      final counts = find.descendant(
        of: find.byType(OrderTabs),
        matching: find.text('1'),
      );
      expect(counts, findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(OrderTabs),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });
  });

  group('order card rendering', () {
    testWidgets('shows the order id, time, items and total', (tester) async {
      final repo = FakeOrderHistoryRepository([newOrder]);

      await pumpOrders(tester, repo);

      expect(find.text('Order #1'), findsOneWidget);
      expect(find.text('Alcohol'), findsOneWidget);
      expect(find.text('× 2'), findsOneWidget);
      expect(find.text('cefalexin'), findsOneWidget);
      expect(find.text('× 1'), findsOneWidget);
      // 6500 * 2 + 4500 * 1 = 17500 centavos.
      expect(find.text('₱175.00'), findsOneWidget);
    });

    testWidgets('shows the status label', (tester) async {
      final repo = FakeOrderHistoryRepository([newOrder]);

      await pumpOrders(tester, repo);

      expect(card('New'), findsOneWidget);
    });

    testWidgets('shows the Approve button for new orders', (tester) async {
      final repo = FakeOrderHistoryRepository([newOrder]);

      await pumpOrders(tester, repo);

      expect(find.text('Approve'), findsOneWidget);
    });

    testWidgets('hides the Approve button for approved orders', (tester) async {
      final repo = FakeOrderHistoryRepository([approvedOrder]);

      await pumpOrders(tester, repo);

      expect(find.text('Approve'), findsNothing);
      expect(card('Approved'), findsOneWidget);
    });
  });

  group('approveOrder', () {
    testWidgets('tapping Approve moves the order to the Approved tab', (
      tester,
    ) async {
      final repo = FakeOrderHistoryRepository([newOrder]);

      await pumpOrders(tester, repo);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // Still on All tab, so the order is still visible but now approved.
      expect(find.text('Order #1'), findsOneWidget);
      expect(card('Approved'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);

      // The New tab should now be empty.
      await tester.tap(tab('New'));
      await tester.pumpAndSettle();
      expect(find.text('Order #1'), findsNothing);
    });
  });

  group('empty states', () {
    testWidgets('shows an empty message when there are no orders', (
      tester,
    ) async {
      final repo = FakeOrderHistoryRepository([]);

      await pumpOrders(tester, repo);

      expect(find.text('No all orders right now.'), findsOneWidget);
    });

    testWidgets('shows an empty message on the New tab when none are new', (
      tester,
    ) async {
      final repo = FakeOrderHistoryRepository([approvedOrder]);

      await pumpOrders(tester, repo);

      await tester.tap(tab('New'));
      await tester.pumpAndSettle();

      expect(find.text('No new orders right now.'), findsOneWidget);
    });

    testWidgets(
      'shows an empty message on the Approved tab when none are approved',
      (tester) async {
        final repo = FakeOrderHistoryRepository([newOrder]);

        await pumpOrders(tester, repo);

await tester.tap(tab('Approved'));
      await tester.pumpAndSettle();

      expect(find.text('No approved orders right now.'), findsOneWidget);
      },
    );
  });
}
