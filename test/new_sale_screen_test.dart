import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/orders/data/repositories/local_order_history_repository.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/orders/presentation/screens/orders_screen.dart';
import 'package:pharmaguide/features/orders/presentation/widgets/order_card.dart';
import 'package:pharmaguide/features/orders/presentation/widgets/order_tabs.dart';
import 'package:pharmaguide/features/sales/presentation/screens/new_sale_screen.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_repository.dart';
import 'package:pharmaguide/features/search/presentation/providers/medicine_provider.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_medicine_store.dart';

void main() {
  const phoneSize = Size(360, 720);
  const alcohol = MedicineModel(
    name: 'Alcohol',
    priceCentavos: 6500,
    stock: 200,
  );

  late FakeAuthRepository repository;
  late AuthProvider auth;
  late FakeMedicineStore store;
  late LocalOrderHistoryRepository history;
  late OrderProvider order;

  setUpAll(() async {
    repository = FakeAuthRepository();
    auth = AuthProvider(repository);
    await auth.ready;
    await auth.login(email: 'a@b.com', password: 'secret');
    store = FakeMedicineStore(initial: const StaticMedicineRepository().all());
    history = LocalOrderHistoryRepository();

    order = OrderProvider(auth: auth, historyFor: (_) => history);
  });

  tearDownAll(() {
    order.dispose();
    history.dispose();
    store.dispose();
    auth.dispose();
    repository.dispose();
  });

  Future<void> pumpNewSaleDirect(WidgetTester tester) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1.0;

    final catalogue = MedicineProvider(auth: auth, storeFor: (_) => store);
    await tester.pumpWidget(
      ChangeNotifierProvider<OrderProvider>.value(
        value: order,
        child: ChangeNotifierProvider<MedicineProvider>.value(
          value: catalogue,
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const NewSaleScreen(),
          ),
        ),
      ),
    );
    await pumpEventQueue();
  }

  Future<void> pumpNewSaleWithRouter(WidgetTester tester) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1.0;

    final catalogue = MedicineProvider(auth: auth, storeFor: (_) => store);

    final router = GoRouter(
      initialLocation: '/new-sale',
      routes: [
        GoRoute(path: '/new-sale', builder: (_, _) => const NewSaleScreen()),
        GoRoute(
          path: '/orders',
          builder: (_, _) => OrdersScreen(historyFactory: () => history),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: ChangeNotifierProvider<OrderProvider>.value(
          value: order,
          child: ChangeNotifierProvider<MedicineProvider>.value(
            value: catalogue,
            child: MaterialApp.router(
              routerConfig: router,
              theme: buildAppTheme(Brightness.light),
            ),
          ),
        ),
      ),
    );
    await pumpEventQueue();

    await tester.tap(find.text('New Sale'));
    await pumpEventQueue();
  }

  Future<void> pumpSaleToOrders(WidgetTester tester) async {
    await pumpNewSaleWithRouter(tester);
  }

  Future<void> tapProceed(WidgetTester tester) async {
    final proceedButton = find.byKey(const Key('proceedButton'));
    await tester.ensureVisible(proceedButton);
    await pumpEventQueue();
    await tester.tap(proceedButton);
    await pumpEventQueue();
    await tester.tap(proceedButton);
    await pumpEventQueue();
  }

  testWidgets('shows search field and scan button', (tester) async {
    await pumpNewSaleDirect(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Scan'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
  });

  testWidgets('shows all products when query is empty', (tester) async {
    await pumpNewSaleDirect(tester);

    expect(find.text('Alcohol'), findsOneWidget);
    expect(find.text('₱65.00'), findsWidgets);
  });

  testWidgets('search filters the product list', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.enterText(find.byType(TextField), 'cefa');
    await pumpEventQueue();

    expect(find.text('cefalexin'), findsOneWidget);
    expect(find.text('Alcohol'), findsNothing);
  });

  testWidgets('clear button restores full product list', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.enterText(find.byType(TextField), 'cefa');
    await pumpEventQueue();
    expect(find.text('cefalexin'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await pumpEventQueue();

    await tester.enterText(find.byType(TextField), 'cefa');
    await pumpEventQueue();
    expect(find.text('cefalexin'), findsOneWidget);
  });

  testWidgets('tapping add button adds item to cart', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await pumpEventQueue();

    expect(order.itemCount, 1);
    expect(order.lines.single.medicine.name, 'Alcohol');
    expect(find.byTooltip('Remove 1 × Alcohol'), findsOneWidget);
  });

  testWidgets('cart section appears when items are added', (tester) async {
    await pumpNewSaleDirect(tester);

    expect(find.text('Cart'), findsNothing);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await pumpEventQueue();

    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('1 items'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('₱65.00'), findsWidgets);
    expect(find.text('Proceed'), findsOneWidget);
  });

  testWidgets('cart shows itemized list with quantity controls', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await pumpEventQueue();

    final cartList = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.text('Alcohol'),
    );
    expect(cartList, findsOneWidget);
    expect(find.byTooltip('One fewer Alcohol'), findsOneWidget);
    expect(find.byTooltip('One more Alcohol'), findsOneWidget);
    expect(find.byTooltip('Remove Alcohol'), findsOneWidget);
    expect(find.text('₱65.00'), findsWidgets);
  });

  testWidgets('quantity adjustment in cart updates line total', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await pumpEventQueue();

    await tester.tap(find.byTooltip('One more Alcohol'));
    await pumpEventQueue();

    expect(order.quantityOf(alcohol), 2);
    expect(find.text('₱130.00'), findsWidgets);
  });

  testWidgets('remove from cart removes item and hides cart section', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await pumpEventQueue();
    expect(find.text('Cart'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Alcohol'));
    await pumpEventQueue();

    expect(order.isEmpty, isTrue);
    expect(find.text('Cart'), findsNothing);
  });

  testWidgets('payment selector starts on cash on hand', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await pumpEventQueue();

    expect(
      find.descendant(
        of: find.byKey(const Key('cartScrollView')),
        matching: find.text('Cash on Hand'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('cartScrollView')),
        matching: find.text('GCash'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('cartScrollView')),
        matching: find.text('Coming soon'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('payment selector changes selection', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await pumpEventQueue();

    double borderWidthOf(String key) {
      final tile = find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).border != null,
        ),
      );
      final container = tester.widget<Container>(tile.first);
      return (container.decoration! as BoxDecoration).border!.top.width;
    }

    expect(borderWidthOf('paymentCashOnHand'), 2.0);
    expect(borderWidthOf('paymentGCash'), 1.0);

    await tester.tap(find.byKey(const Key('paymentGCash')));
    await pumpEventQueue();

    expect(borderWidthOf('paymentGCash'), 2.0);
    expect(borderWidthOf('paymentCashOnHand'), 1.0);

    expect(
      find.descendant(
        of: find.byKey(const Key('cartScrollView')),
        matching: find.text('GCash'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('proceed button shows confirm dialog with Continue option', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await pumpEventQueue();

    await tapProceed(tester);

    expect(find.text('Confirm Sale'), findsOneWidget);
    expect(find.text('Complete this sale with Cash on Hand?'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Go to Orders'), findsNothing);
  });

  testWidgets('cancel on dialog keeps cart intact', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await pumpEventQueue();

    await tapProceed(tester);

    await tester.tap(find.text('Cancel'));
    await pumpEventQueue();

    expect(order.itemCount, 1);
    expect(find.text('Cart'), findsOneWidget);
  });

  testWidgets('scan button navigates to scan screen', (tester) async {
    await pumpNewSaleWithRouter(tester);

    await tester.tap(find.byTooltip('Scan'));
    await pumpEventQueue();

    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('multiple items show correct total in cart', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await pumpEventQueue();

    await tester.enterText(find.byType(TextField), 'cefa');
    await pumpEventQueue();
    await tester.tap(find.byTooltip('Add cefalexin'));
    await pumpEventQueue();

    expect(order.itemCount, 2);
    expect(order.formattedTotal, '₱110.00');
  });

  group('completing a sale', () {
    testWidgets('lands the order on the Orders tab as New', (tester) async {
      await pumpSaleToOrders(tester);

      await tester.tap(find.byTooltip('Add Alcohol'));
      await pumpEventQueue();
      await tester.enterText(find.byType(TextField), 'cefa');
      await pumpEventQueue();
      await tester.tap(find.byTooltip('Add cefalexin'));
      await pumpEventQueue();
      expect(order.itemCount, 2);

      await tapProceed(tester);
      await tester.tap(find.text('Continue'));
      await pumpEventQueue();

      expect(order.isEmpty, isTrue);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Order #'), findsOneWidget);
      expect(find.text('Alcohol'), findsOneWidget);
      expect(find.text('cefalexin'), findsOneWidget);
      expect(find.text('× 1'), findsNWidgets(2));
      expect(find.text('₱110.00'), findsOneWidget);

      expect(
        find.descendant(of: find.byType(OrderCard), matching: find.text('New')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(OrderCard),
          matching: find.text('Approve'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the new order shows under the New tab', (tester) async {
      await pumpSaleToOrders(tester);

      await tester.tap(find.byTooltip('Add Alcohol'));
      await pumpEventQueue();
      await tapProceed(tester);
      await tester.tap(find.text('Continue'));
      await pumpEventQueue();

      await tester.tap(
        find.descendant(of: find.byType(OrderTabs), matching: find.text('New')),
      );
      await pumpEventQueue();

      expect(
        find.descendant(of: find.byType(OrderCard), matching: find.text('New')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(OrderTabs),
          matching: find.text('Approved'),
        ),
      );
      await pumpEventQueue();

      expect(find.byType(OrderCard), findsNothing);
      expect(find.text('No approved orders right now.'), findsOneWidget);
    });

    testWidgets('approving moves it out of New and into Approved', (tester) async {
      await pumpSaleToOrders(tester);

      await tester.tap(find.byTooltip('Add Alcohol'));
      await pumpEventQueue();
      await tapProceed(tester);
      await tester.tap(find.text('Continue'));
      await pumpEventQueue();

      await tester.tap(
        find.descendant(
          of: find.byType(OrderCard),
          matching: find.text('Approve'),
        ),
      );
      await pumpEventQueue();

      expect(
        find.descendant(
          of: find.byType(OrderCard),
          matching: find.text('Approved'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(OrderTabs),
          matching: find.text('New'),
        ),
      );
      await pumpEventQueue();

      expect(find.text('No new orders right now.'), findsOneWidget);
    });
  });
}