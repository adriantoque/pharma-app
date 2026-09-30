import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/orders/presentation/screens/orders_screen.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:provider/provider.dart';

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

  late OrderProvider order;

  setUp(() => order = OrderProvider());
  tearDown(() => order.dispose());

  Future<void> pumpOrders(WidgetTester tester) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<OrderProvider>.value(
        value: order,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const OrdersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The grand total, read by key rather than by text.
  ///
  /// A one-item order totals exactly the same as that line, so `find.text` on the
  /// peso amount matches both and the assertion could not say which it read.
  String grandTotal(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('orderTotal'))).data!;

  /// The sticky item count, read by key for the same reason.
  String itemCount(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('orderItemCount'))).data!;

  testWidgets('an empty order explains where to add items', (tester) async {
    await pumpOrders(tester);

    // nav_alignment_test.dart and widget_test.dart both use this string as the
    // marker proving the Orders branch is on top, so it has to stay distinct
    // from the navigation label 'Orders'.
    expect(find.text('Nothing in this order yet'), findsOneWidget);
    expect(
      find.text('Find an item in Search and tap the + to add it.'),
      findsOneWidget,
    );
    expect(find.text('Total'), findsNothing);
  });

  testWidgets('lines show the unit price, the count and the line total', (
    tester,
  ) async {
    order.add(alcohol, 2);
    order.add(cefalexin, 1);

    await pumpOrders(tester);

    expect(find.text('Alcohol'), findsOneWidget);
    expect(find.text('₱65.00 × 2'), findsOneWidget);

    expect(find.text('cefalexin'), findsOneWidget);
    expect(find.text('₱45.00 × 1'), findsOneWidget);

    // 6500 * 2 + 4500 * 1.
    expect(grandTotal(tester), '₱175.00');
  });

  testWidgets('the summary counts units and sums the money', (tester) async {
    order.add(alcohol, 2);
    order.add(cefalexin, 3);

    await pumpOrders(tester);

    // Units, not lines: five across two things is five items.
    expect(itemCount(tester), '5 items');
    // 6500 * 2 + 4500 * 3.
    expect(grandTotal(tester), '₱265.00');
  });

  testWidgets('a single unit is not called "1 items"', (tester) async {
    order.add(alcohol, 1);

    await pumpOrders(tester);

    expect(itemCount(tester), '1 item');
    expect(find.text('1 items'), findsNothing);
  });

  testWidgets('the quantity can be changed in place', (tester) async {
    order.add(alcohol, 2);

    await pumpOrders(tester);

    await tester.tap(find.byTooltip('One more Alcohol'));
    await tester.pumpAndSettle();
    expect(order.quantityOf(alcohol), 3);
    expect(find.text('₱65.00 × 3'), findsOneWidget);
    // 6500 * 3.
    expect(grandTotal(tester), '₱195.00');

    await tester.tap(find.byTooltip('One fewer Alcohol'));
    await tester.pumpAndSettle();
    expect(order.quantityOf(alcohol), 2);
    expect(find.text('₱65.00 × 2'), findsOneWidget);
    expect(grandTotal(tester), '₱130.00');
  });

  testWidgets('stepping down from one removes the line', (tester) async {
    order.add(alcohol, 1);

    await pumpOrders(tester);

    await tester.tap(find.byTooltip('One fewer Alcohol'));
    await tester.pumpAndSettle();

    // Back to the empty state rather than a line reading "0".
    expect(order.isEmpty, isTrue);
    expect(find.text('Nothing in this order yet'), findsOneWidget);
  });

  testWidgets('a line can be deleted outright', (tester) async {
    order.add(alcohol, 2);
    order.add(cefalexin, 1);

    await pumpOrders(tester);

    await tester.tap(find.byTooltip('Remove Alcohol'));
    await tester.pumpAndSettle();

    expect(find.text('Alcohol'), findsNothing);
    expect(find.text('cefalexin'), findsOneWidget);
    expect(find.text('₱45.00 × 1'), findsOneWidget);
    // Only the surviving item is left to total.
    expect(grandTotal(tester), '₱45.00');
  });

  testWidgets('the increase control is disabled at the cap', (tester) async {
    order.add(alcohol, OrderProvider.maxQuantity);

    await pumpOrders(tester);

    // IconButton builds its own Tooltip *inside* itself, so the button is the
    // tooltip's ancestor. Scoped by tooltip rather than keyed because a key would
    // have to be unique per line and byTooltip already names the line.
    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('One more Alcohol'),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
    // 6500 * 99, which is where a mistyped 999999 would otherwise only be noticed
    // on the receipt.
    expect(grandTotal(tester), '₱6435.00');
  });

  testWidgets('a long line does not overflow a narrow phone', (tester) async {
    const longest = MedicineModel(
      name: 'paracetamol 125',
      priceCentavos: 4500,
      stock: 200,
    );
    order.add(longest, 12);

    await pumpOrders(tester);

    expect(find.text('paracetamol 125'), findsOneWidget);
    expect(find.text('₱45.00 × 12'), findsOneWidget);
    // Two digits in the stepper have to fit beside the name and the money.
    expect(grandTotal(tester), '₱540.00');
    expect(tester.takeException(), isNull);
  });

  group('capped by the shelf', () {
    const scarce = MedicineModel(name: 'scarce', priceCentavos: 1000, stock: 2);
    const plentiful = MedicineModel(
      name: 'plentiful',
      priceCentavos: 1000,
      stock: 200,
    );

    testWidgets('the increase stops at the shelf, not at the order limit', (
      tester,
    ) async {
      // The same provider clamp as above, seen from the list: a line cannot be
      // walked past what the shelf holds.
      order.add(scarce, 1);

      await pumpOrders(tester);

      await tester.tap(find.byTooltip('One more scarce'));
      await tester.pumpAndSettle();
      expect(order.quantityOf(scarce), 2);

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('One more scarce'),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(grandTotal(tester), '₱20.00');
    });

    testWidgets('an item with plenty still stops at the order limit', (
      tester,
    ) async {
      order.add(plentiful, OrderProvider.maxQuantity);

      await pumpOrders(tester);

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('One more plentiful'),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(grandTotal(tester), '₱990.00');
    });
  });
}
