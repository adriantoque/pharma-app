import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/orders/data/models/order_history_model.dart';
import 'package:pharmaguide/features/orders/data/models/order_line_model.dart';
import 'package:pharmaguide/features/orders/data/repositories/order_history_repository.dart';
import 'package:pharmaguide/features/orders/presentation/providers/orders_provider.dart';
import 'package:pharmaguide/features/orders/presentation/screens/order_history_screen.dart';
import 'package:pharmaguide/features/orders/presentation/screens/orders_screen.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/presentation/providers/medicine_provider.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_medicine_store.dart';
import 'helpers/fake_order_history_repository.dart';

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

  final rejectedOrder = order(
    id: '3',
    time: DateTime(2025, 8, 1, 8, 0),
    status: OrderStatus.rejected,
    items: [OrderLineModel(medicine: alcohol, quantity: 1)],
  );

  /// Wires the providers [OrdersScreen] reads: the auth user (for the uid), the
  /// per-user repository factory, the provider the approve/reject buttons write
  /// through, and the catalogue an approved order takes its stock from.
  ///
  /// Returns the fake store so a test can read what the approval wrote to it.
  Future<FakeMedicineStore> pumpOrders(
    WidgetTester tester,
    FakeOrderHistoryRepository repository,
  ) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final authRepository = FakeAuthRepository();
    final auth = AuthProvider(authRepository);
    await auth.ready;
    await auth.login(email: 'a@b.com', password: 'secret');

    final ordersProvider = OrdersProvider(historyFactory: () => repository);

    final store = FakeMedicineStore(initial: const [alcohol, cefalexin]);
    final catalogue = MedicineProvider(auth: auth, storeFor: (_) => store);

    addTearDown(auth.dispose);
    addTearDown(authRepository.dispose);
    addTearDown(repository.dispose);
    addTearDown(ordersProvider.dispose);
    addTearDown(catalogue.dispose);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          Provider<OrderHistoryRepositoryFactory>.value(
            value: (_) => repository,
          ),
          ChangeNotifierProvider<OrdersProvider>.value(value: ordersProvider),
          ChangeNotifierProvider<MedicineProvider>.value(value: catalogue),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const OrdersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return store;
  }

  group('OrdersScreen (pending orders)', () {
    testWidgets('shows the id, lines and total of a new order', (tester) async {
      final repo = FakeOrderHistoryRepository([newOrder]);

      await pumpOrders(tester, repo);

      expect(find.text('Order #1'), findsOneWidget);
      // The expansion is collapsed, so only the summary is on screen.
      expect(find.textContaining('3 items'), findsOneWidget);
      // 6500 * 2 + 4500 * 1 = 17500 centavos.
      expect(find.text('₱175.00'), findsOneWidget);
    });

    testWidgets('hides orders that are no longer pending', (tester) async {
      final repo = FakeOrderHistoryRepository([approvedOrder, rejectedOrder]);

      await pumpOrders(tester, repo);

      expect(find.text('Order #2'), findsNothing);
      expect(find.text('Order #3'), findsNothing);
      expect(find.text('No orders waiting'), findsOneWidget);
    });

    testWidgets('shows the empty state when there is nothing pending', (
      tester,
    ) async {
      final repo = FakeOrderHistoryRepository();

      await pumpOrders(tester, repo);

      expect(find.text('No orders waiting'), findsOneWidget);
    });

    testWidgets('approving removes the order from the pending list', (
      tester,
    ) async {
      final repo = FakeOrderHistoryRepository([newOrder]);

      await pumpOrders(tester, repo);

      // The card must be expanded before its action buttons are built.
      await tester.tap(find.text('Order #1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('Order #1'), findsNothing);
      expect(find.text('No orders waiting'), findsOneWidget);

      // The decision reached the repository.
      expect(
        repo.orders.firstWhere((o) => o.id == '1').status,
        OrderStatus.approved,
      );
    });

    testWidgets('approving takes the ordered units off the shelf', (
      tester,
    ) async {
      final repo = FakeOrderHistoryRepository([newOrder]);

      final store = await pumpOrders(tester, repo);

      // The card must be expanded before its action buttons are built.
      await tester.tap(find.text('Order #1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // newOrder holds 2 x Alcohol (200) and 1 x cefalexin (200).
      expect(store.operations, contains('setStock Alcohol -> 198'));
      expect(store.operations, contains('setStock cefalexin -> 199'));
    });

    testWidgets('rejecting asks for confirmation, then removes the order', (
      tester,
    ) async {
      final repo = FakeOrderHistoryRepository([newOrder]);

      await pumpOrders(tester, repo);

      // The card must be expanded before its action buttons are on screen.
      await tester.tap(find.text('Order #1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(find.text('Reject this order?'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(OutlinedButton, 'Reject'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order #1'), findsNothing);
      expect(
        repo.orders.firstWhere((o) => o.id == '1').status,
        OrderStatus.rejected,
      );
    });

    testWidgets('shows an error body when the stream fails', (tester) async {
      final repo = FakeOrderHistoryRepository([newOrder])
        ..readError = Exception('offline');

      await pumpOrders(tester, repo);

      expect(find.text('Orders could not be loaded'), findsOneWidget);
    });
  });

  group('OrderHistoryScreen', () {
    Future<void> pumpHistory(
      WidgetTester tester,
      FakeOrderHistoryRepository repository,
    ) async {
      tester.view.physicalSize = phoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final authRepository = FakeAuthRepository();
      final auth = AuthProvider(authRepository);
      await auth.ready;
      await auth.login(email: 'a@b.com', password: 'secret');

      addTearDown(auth.dispose);
      addTearDown(authRepository.dispose);
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            Provider<OrderHistoryRepositoryFactory>.value(
              value: (_) => repository,
            ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const OrderHistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists decided orders with their status', (tester) async {
      final repo = FakeOrderHistoryRepository([approvedOrder, rejectedOrder]);

      await pumpHistory(tester, repo);

      expect(find.text('Order #2'), findsOneWidget);
      expect(find.text('Order #3'), findsOneWidget);
    });

    testWidgets('the Approved filter hides rejected orders', (tester) async {
      final repo = FakeOrderHistoryRepository([approvedOrder, rejectedOrder]);

      await pumpHistory(tester, repo);

      await tester.tap(find.textContaining('Approved'));
      await tester.pumpAndSettle();

      expect(find.text('Order #2'), findsOneWidget);
      expect(find.text('Order #3'), findsNothing);
    });

    testWidgets('search matches the medicine name on an order', (tester) async {
      // Both are approved so the default "All" filter keeps them visible;
      // ordering keeps the two distinguishable.
      final cefOnly = order(
        id: '10',
        time: DateTime(2025, 8, 4),
        status: OrderStatus.approved,
        items: [OrderLineModel(medicine: cefalexin, quantity: 1)],
      );
      final alcoholOnly = order(
        id: '11',
        time: DateTime(2025, 8, 5),
        status: OrderStatus.approved,
        items: [OrderLineModel(medicine: alcohol, quantity: 1)],
      );
      final repo = FakeOrderHistoryRepository([cefOnly, alcoholOnly]);

      await pumpHistory(tester, repo);

      await tester.enterText(find.byType(TextField), 'cefa');
      await tester.pumpAndSettle();

      expect(find.text('Order #10'), findsOneWidget);
      expect(find.text('Order #11'), findsNothing);
    });

    testWidgets('shows the empty state when there is no history', (
      tester,
    ) async {
      final repo = FakeOrderHistoryRepository();

      await pumpHistory(tester, repo);

      expect(find.text('No orders in history yet'), findsOneWidget);
    });
  });
}
