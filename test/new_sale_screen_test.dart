import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/sales/domain/payment_method.dart';
import 'package:pharmaguide/features/sales/presentation/screens/cart_screen.dart';
import 'package:pharmaguide/features/sales/presentation/screens/new_sale_screen.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_repository.dart';
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

  /// Everything a sale screen needs, built fresh per test and torn down with it.
  ///
  /// A signed-in [AuthProvider] is required because both [OrderProvider] and
  /// [MedicineProvider] resolve their per-user store from it.
  Future<({OrderProvider order, FakeOrderHistoryRepository history})> pumpSale(
    WidgetTester tester, {
    List<MedicineModel>? initial,
    bool withRouter = false,
    FakeOrderHistoryRepository? history,
  }) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final authRepository = FakeAuthRepository();
    final auth = AuthProvider(authRepository);
    await auth.ready;
    await auth.login(email: 'a@b.com', password: 'secret');

    final store = FakeMedicineStore(
      initial: initial ?? StaticMedicineRepository().all(),
    );
    final catalogue = MedicineProvider(auth: auth, storeFor: (_) => store);
    final resolvedHistory = history ?? FakeOrderHistoryRepository();
    final order = OrderProvider(
      auth: auth,
      catalogue: catalogue,
      historyFor: (_) => resolvedHistory,
    );

    addTearDown(() {
      order.dispose();
      resolvedHistory.dispose();
      store.dispose();
      catalogue.dispose();
      auth.dispose();
      authRepository.dispose();
    });

    final providers = [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<OrderProvider>.value(value: order),
      ChangeNotifierProvider<MedicineProvider>.value(value: catalogue),
    ];

    if (withRouter) {
      final router = GoRouter(
        initialLocation: '/new-sale',
        routes: [
          GoRoute(
            path: '/new-sale',
            name: 'new-sale',
            builder: (_, _) => const NewSaleScreen(),
            routes: [
              GoRoute(
                path: 'cart',
                name: 'new-sale-cart',
                builder: (_, state) => CartScreen(
                  initialPayment:
                      state.extra as PaymentMethod? ?? PaymentMethod.cashOnHand,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/home-scan',
            name: 'home-scan',
            builder: (_, _) => const Scaffold(body: Text('Scan Screen')),
          ),
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (_, _) => const Scaffold(body: Text('Home Screen')),
          ),
          GoRoute(
            path: '/orders',
            name: 'orders',
            builder: (_, _) => const Scaffold(body: Text('Orders Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildAppTheme(Brightness.light),
          ),
        ),
      );
    } else {
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const NewSaleScreen(),
          ),
        ),
      );
    }

    await tester.pumpAndSettle();
    return (order: order, history: resolvedHistory);
  }

  group('NewSaleScreen', () {
    testWidgets('shows the search field, scan button and product list', (
      tester,
    ) async {
      await pumpSale(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Scan'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Alaxan FR Capsule'), findsOneWidget);
    });

    testWidgets('hides products whose stock has not been counted', (
      tester,
    ) async {
      await pumpSale(
        tester,
        initial: [
          ...StaticMedicineRepository().all(),
          const MedicineModel(
            name: 'Uncounted',
            priceCentavos: 100,
            stock: null,
          ),
        ],
      );

      expect(find.text('Uncounted'), findsNothing);
    });

    testWidgets('search filters the product list', (tester) async {
      await pumpSale(tester);

      await tester.enterText(find.byType(TextField), 'amox');
      await tester.pumpAndSettle();

      expect(
        find.text('Amoxil 500mg Capsule (Amoxicillin)'),
        findsOneWidget,
      );
      expect(find.text('Alaxan FR Capsule'), findsNothing);
    });

    testWidgets('clear restores the full product list', (tester) async {
      await pumpSale(tester);

      await tester.enterText(find.byType(TextField), 'amox');
      await tester.pumpAndSettle();
      expect(find.text('Alaxan FR Capsule'), findsNothing);

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Alaxan FR Capsule'), findsOneWidget);
    });

    testWidgets('add puts a line in the order', (tester) async {
      final sale = await pumpSale(tester);

      await tester.tap(find.byTooltip('Add Alaxan FR Capsule'));
      await tester.pumpAndSettle();

      expect(sale.order.itemCount, 1);
      expect(sale.order.lines.single.medicine.name, 'Alaxan FR Capsule');
      expect(
        find.byTooltip('Remove 1 × Alaxan FR Capsule'),
        findsOneWidget,
      );
    });

    testWidgets('an out-of-stock item cannot be added', (tester) async {
      // 'Allerkid 2.5mg/mL Oral Drops' is in the static list at stock 0.
      final sale = await pumpSale(tester);

      await tester.tap(
        find.byTooltip('Add Allerkid 2.5mg/mL Oral Drops 10mL'),
      );
      await tester.pumpAndSettle();

      expect(sale.order.isEmpty, isTrue);
    });

    testWidgets('the cart icon opens the cart once an item is added', (
      tester,
    ) async {
      await pumpSale(tester, withRouter: true);

      await tester.tap(find.byTooltip('Add Alaxan FR Capsule'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('View cart'));
      await tester.pumpAndSettle();

      expect(find.text('Cart · 1 item'), findsOneWidget);
      expect(find.text('Proceed'), findsOneWidget);
    });

    testWidgets('the scan button opens the scan screen', (tester) async {
      await pumpSale(tester, withRouter: true);

      await tester.tap(find.byTooltip('Scan'));
      await tester.pumpAndSettle();

      expect(find.text('Scan Screen'), findsOneWidget);
    });
  });

  /// Builds a cart directly, with [order] already holding [lines] worth of
  /// [alcohol]. Cart-only behaviour is tested without routing through a sale.
  Future<OrderProvider> pumpCart(
    WidgetTester tester, {
    required int quantity,
  }) async {
    final sale = await pumpSale(tester, withRouter: true);
    sale.order.add(alcohol, quantity);
    await tester.pumpAndSettle();

    // Push the cart onto the sale screen so pops have somewhere to return to.
    final context = tester.element(find.byType(NewSaleScreen));
    context.pushNamed(
      'new-sale-cart',
      extra: PaymentMethod.cashOnHand,
    );
    await tester.pumpAndSettle();
    return sale.order;
  }

  group('CartScreen', () {
    testWidgets('shows the lines, item count, total and Proceed', (
      tester,
    ) async {
      await pumpCart(tester, quantity: 2);

      expect(find.text('Cart · 2 items'), findsOneWidget);
      expect(find.text('Alcohol'), findsOneWidget);
      // 6500 * 2 = 13000 centavos.
      expect(find.text('₱130.00'), findsWidgets);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Proceed'), findsOneWidget);
    });

    testWidgets('increasing the quantity updates the total', (tester) async {
      final order = await pumpCart(tester, quantity: 1);

      await tester.tap(find.byTooltip('One more Alcohol'));
      await tester.pumpAndSettle();

      expect(order.quantityOf(alcohol), 2);
      expect(find.text('₱130.00'), findsWidgets);
    });

    testWidgets('removing the only line shows the empty cart', (tester) async {
      final order = await pumpCart(tester, quantity: 1);

      await tester.tap(find.byTooltip('Remove Alcohol'));
      await tester.pumpAndSettle();

      expect(order.isEmpty, isTrue);
      expect(find.text('Your cart is empty.'), findsOneWidget);
    });

    testWidgets('selecting GCash moves the selection', (tester) async {
      await pumpCart(tester, quantity: 1);

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
      await tester.pumpAndSettle();

      expect(borderWidthOf('paymentGCash'), 2.0);
      expect(borderWidthOf('paymentCashOnHand'), 1.0);
    });

    testWidgets('clearing the cart asks first, then empties it', (tester) async {
      final order = await pumpCart(tester, quantity: 2);

      await tester.tap(find.byTooltip('Clear cart'));
      await tester.pumpAndSettle();
      expect(find.text('Clear cart?'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(order.isEmpty, isTrue);
      expect(find.text('Your cart is empty.'), findsOneWidget);
    });
  });

  group('completing a sale', () {
    testWidgets('proceeding on the cart confirms, then lands on Orders', (
      tester,
    ) async {
      final sale = await pumpSale(tester, withRouter: true);

      await tester.tap(find.byTooltip('Add Alaxan FR Capsule'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('View cart'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('proceedButton')));
      await tester.pumpAndSettle();

      // Proceed pops the cart, and the sale screen asks to confirm.
      expect(find.text('Confirm Sale'), findsOneWidget);
      expect(find.text('Complete this sale with Cash on Hand?'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(sale.order.isEmpty, isTrue);
      expect(
        sale.history.orders.single.items.single.medicine.name,
        'Alaxan FR Capsule',
      );
      expect(find.text('Orders Screen'), findsOneWidget);
    });

    testWidgets('cancelling the confirm keeps the cart intact', (tester) async {
      final sale = await pumpSale(tester, withRouter: true);

      await tester.tap(find.byTooltip('Add Alaxan FR Capsule'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('View cart'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('proceedButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(sale.order.itemCount, 1);
      expect(sale.history.orders, isEmpty);
    });
  });
}
