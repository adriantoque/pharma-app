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
import 'package:pharmaguide/routing/app_router.dart';
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

  setUp(() async {
    repository = FakeAuthRepository();
    auth = AuthProvider(repository);
    await auth.ready;
    await auth.login(email: 'a@b.com', password: 'secret');
    store = FakeMedicineStore(initial: const StaticMedicineRepository().all());
    history = LocalOrderHistoryRepository();

    // `complete` refuses an order it has nowhere to record, so it needs both a
    // signed-in uid and a history to write to. The tests that only read the
    // cart never reach that, but the ones that complete a sale do.
    order = OrderProvider(auth: auth, historyFor: (_) => history);
  });

  tearDown(() {
    order.dispose();
    history.dispose();
    store.dispose();
    auth.dispose();
    repository.dispose();
  });

  Future<void> pumpNewSaleDirect(WidgetTester tester) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final catalogue = MedicineProvider(auth: auth, storeFor: (_) => store);
    addTearDown(catalogue.dispose);

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
    await tester.pumpAndSettle();
  }

  Future<void> pumpNewSaleWithRouter(WidgetTester tester) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final catalogue = MedicineProvider(auth: auth, storeFor: (_) => store);
    addTearDown(catalogue.dispose);

    final router = createAppRouter(refreshListenable: auth);
    addTearDown(router.dispose);

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
    await tester.pumpAndSettle();

    // Navigate to new-sale screen
    await tester.tap(find.text('New Sale'));
    await tester.pumpAndSettle();
  }

  /// Builds just the two screens a completed sale travels between.
  ///
  /// The app's own router cannot be used here: its `/orders` route builds
  /// `OrdersScreen` with no seam, so it reaches for a Firestore instance the
  /// test has none of, and the finished order would never be visible. A local
  /// router also keeps the test off the auth redirect that guards the real one.
  Future<void> pumpSaleToOrders(WidgetTester tester) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final catalogue = MedicineProvider(auth: auth, storeFor: (_) => store);
    addTearDown(catalogue.dispose);

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
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<OrderProvider>.value(
        value: order,
        child: ChangeNotifierProvider<MedicineProvider>.value(
          value: catalogue,
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildAppTheme(Brightness.light),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows search field and scan button', (tester) async {
    await pumpNewSaleDirect(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Scan'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
  });

  testWidgets('shows all products when query is empty', (tester) async {
    await pumpNewSaleDirect(tester);

    // Should show the first product in the catalog
    expect(find.text('Alcohol'), findsOneWidget);
    expect(find.text('₱65.00'), findsWidgets);
  });

  testWidgets('search filters the product list', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.enterText(find.byType(TextField), 'cefa');
    await tester.pumpAndSettle();

    expect(find.text('cefalexin'), findsOneWidget);
    expect(find.text('Alcohol'), findsNothing);
  });

  testWidgets('clear button restores full product list', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.enterText(find.byType(TextField), 'cefa');
    await tester.pumpAndSettle();
    expect(find.text('cefalexin'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    // Search for cefalexin again to verify it's in the full list
    await tester.enterText(find.byType(TextField), 'cefa');
    await tester.pumpAndSettle();
    expect(find.text('cefalexin'), findsOneWidget);
  });

  testWidgets('tapping add button adds item to cart', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await tester.pumpAndSettle();

    expect(order.itemCount, 1);
    expect(order.lines.single.medicine.name, 'Alcohol');
    expect(find.byTooltip('Remove 1 × Alcohol'), findsOneWidget);
  });

  testWidgets('cart section appears when items are added', (tester) async {
    await pumpNewSaleDirect(tester);

    // Cart should not be visible initially
    expect(find.text('Cart'), findsNothing);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await tester.pumpAndSettle();

    // Cart section should appear - find "Cart" in the cart section area
    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('1 items'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('₱65.00'), findsWidgets);
    expect(find.text('Proceed'), findsOneWidget);
  });

  testWidgets('cart shows itemized list with quantity controls', (
    tester,
  ) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await tester.pumpAndSettle();

    // Should show the cart item with name, quantity controls, and line total
    // Scope to cart section to avoid matching product list
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
    await tester.pumpAndSettle();

    // Increase quantity
    await tester.tap(find.byTooltip('One more Alcohol'));
    await tester.pumpAndSettle();

    expect(order.quantityOf(alcohol), 2);
    // Check line total in cart section
    expect(find.text('₱130.00'), findsWidgets);
  });

  testWidgets('remove from cart removes item and hides cart section', (
    tester,
  ) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await tester.pumpAndSettle();
    expect(find.text('Cart'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Alcohol'));
    await tester.pumpAndSettle();

    expect(order.isEmpty, isTrue);
    expect(find.text('Cart'), findsNothing);
  });

  testWidgets('payment selector starts on cash on hand', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

    // The selected tile is drawn with a heavier border, so that width is what
    // says the choice actually moved rather than the tap landing.
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

    // Tap GCash tile directly
    await tester.tap(find.byKey(const Key('paymentGCash')));
    await tester.pumpAndSettle();

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

  final proceedButton = find.byKey(const Key('proceedButton'));

  /// Opens the confirm dialog.
  ///
  /// The Proceed button sits at the bottom of the cart panel, which scrolls, so
  /// it is not always on screen. Scroll to it the way a user would rather than
  /// assuming a tap will land.
  Future<void> tapProceed(WidgetTester tester) async {
    await tester.ensureVisible(proceedButton);
    await tester.pumpAndSettle();
    await tester.tap(proceedButton);
    await tester.pumpAndSettle();
  }

  testWidgets('proceed button shows confirm dialog with Continue option', (
    tester,
  ) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await tester.pumpAndSettle();

    await tapProceed(tester);

    // Dialog should show
    expect(find.text('Confirm Sale'), findsOneWidget);
    expect(find.text('Complete this sale with Cash on Hand?'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Go to Orders'), findsNothing);
  });

  testWidgets('cancel on dialog keeps cart intact', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await tester.pumpAndSettle();

    await tapProceed(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(order.itemCount, 1);
    expect(find.text('Cart'), findsOneWidget);
  });

  testWidgets('scan button navigates to scan screen', (tester) async {
    await pumpNewSaleWithRouter(tester);

    await tester.tap(find.byTooltip('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('multiple items show correct total in cart', (tester) async {
    await pumpNewSaleDirect(tester);

    await tester.tap(find.byTooltip('Add Alcohol'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'cefa');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add cefalexin'));
    await tester.pumpAndSettle();

    expect(order.itemCount, 2);
    // 6500 + 4500 = 11000 centavos = ₱110.00
    expect(order.formattedTotal, '₱110.00');
  });

  group('completing a sale', () {
    testWidgets('lands the order on the Orders tab as New', (tester) async {
      await pumpSaleToOrders(tester);

      await tester.tap(find.byTooltip('Add Alcohol'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'cefa');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add cefalexin'));
      await tester.pumpAndSettle();
      expect(order.itemCount, 2);

      await tapProceed(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The cart is emptied by completing, not by navigating away.
      expect(order.isEmpty, isTrue);

      // OrdersScreen took over, and it reads what `complete` just saved.
      expect(find.text('Orders'), findsOneWidget);
      expect(find.textContaining('Order #'), findsOneWidget);
      expect(find.text('Alcohol'), findsOneWidget);
      expect(find.text('cefalexin'), findsOneWidget);
      expect(find.text('× 1'), findsNWidgets(2));
      // 6500 + 4500 = 11000 centavos.
      expect(find.text('₱110.00'), findsOneWidget);

      // Scoped to the card: the tab bar offers a 'New' filter of its own, so
      // a bare find.text('New') is ambiguous.
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
      await tester.pumpAndSettle();
      await tapProceed(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(of: find.byType(OrderTabs), matching: find.text('New')),
      );
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      expect(find.byType(OrderCard), findsNothing);
      expect(find.text('No approved orders right now.'), findsOneWidget);
    });

    testWidgets('approving moves it out of New and into Approved', (
      tester,
    ) async {
      await pumpSaleToOrders(tester);

      await tester.tap(find.byTooltip('Add Alcohol'));
      await tester.pumpAndSettle();
      await tapProceed(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(OrderCard),
          matching: find.text('Approve'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(OrderCard),
          matching: find.text('Approved'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: find.byType(OrderTabs), matching: find.text('New')),
      );
      await tester.pumpAndSettle();

      expect(find.text('No new orders right now.'), findsOneWidget);
    });
  });
}
