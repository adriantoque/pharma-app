import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_repository.dart';
import 'package:pharmaguide/features/search/presentation/providers/medicine_provider.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_medicine_store.dart';

void main() {
  // Matches the test device: 720x1440 at 320dpi is 360x720 logical.
  const phoneSize = Size(360, 720);

  late FakeAuthRepository repository;
  late AuthProvider auth;
  late FakeMedicineStore store;
  late OrderProvider order;

  setUp(() async {
    repository = FakeAuthRepository();
    auth = AuthProvider(repository);
    await auth.ready;
    // Sign in first: MedicineProvider reads `auth.user` the moment it is
    // constructed, so building it before the session exists yields a provider
    // that never receives a catalogue.
    await auth.login(email: 'a@b.com', password: 'secret');
    // Seeded with the fixed 64-item price list, the same trick
    // nav_alignment_test.dart uses.
    store = FakeMedicineStore(initial: const StaticMedicineRepository().all());
    order = OrderProvider();
  });

  tearDown(() {
    order.dispose();
    store.dispose();
    auth.dispose();
    repository.dispose();
  });

  Future<void> pumpHome(WidgetTester tester, {String query = ''}) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final catalogue = MedicineProvider(auth: auth, storeFor: (_) => store);
    addTearDown(catalogue.dispose);

    // The real provider path, not a static list handed to the screen. The
    // catalogue arrives as a stream event, so the seeded list depends on the
    // pumpAndSettle below.
    await tester.pumpWidget(
      ChangeNotifierProvider<OrderProvider>.value(
        value: order,
        child: ChangeNotifierProvider<MedicineProvider>.value(
          value: catalogue,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (query.isNotEmpty) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the browse state shows the count, the tiles and no rows', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('64 items'), findsOneWidget);
    // The tiles are Home's quick access.
    expect(find.text('Expiring Meds'), findsOneWidget);
    expect(find.text('Scan Prescription'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    // No result rows are built while nobody is searching.
    expect(find.text('Alcohol'), findsNothing);
  });

  testWidgets('a query shows the first alphabetic row and formatted prices', (
    tester,
  ) async {
    await pumpHome(tester, query: 'a');

    expect(find.text('Alcohol'), findsOneWidget);
    // Prices are formatted, not raw centavos.
    expect(find.text('₱65.00'), findsWidgets);
  });

  testWidgets('typing filters the list', (tester) async {
    await pumpHome(tester);

    await tester.enterText(find.byType(TextField), 'amox');
    await tester.pumpAndSettle();

    expect(find.text('4 of 64 items'), findsOneWidget);
    expect(find.text('Amox 500mg'), findsOneWidget);
    expect(find.text('Alcohol'), findsNothing);
  });

  testWidgets('changing the query returns the list to the top', (
    tester,
  ) async {
    await pumpHome(tester, query: 'v');

    // A broad query that still matches enough to scroll; the browse state has
    // no scrolling list at all, and an empty-query finder would match the
    // zero-height results list *and* the tiles list and throw on the fling.
    await tester.fling(find.byType(ListView), const Offset(0, -4000), 4000);
    await tester.pumpAndSettle();
    expect(find.text('vicks'), findsOneWidget);

    // A query that still matches plenty of items, so the list does not shrink
    // below the viewport and clamp the offset by accident.
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();

    expect(find.text('Alcohol'), findsOneWidget);
    expect(find.text('vicks'), findsNothing);
  });

  testWidgets('the clear button restores the browse state', (tester) async {
    await pumpHome(tester);

    await tester.enterText(find.byType(TextField), 'amox');
    await tester.pumpAndSettle();
    expect(find.text('4 of 64 items'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('64 items'), findsOneWidget);
    // Clearing hands the space back to the tiles, which is what Home shows when
    // nobody is searching -- not the full result list.
    expect(find.text('Expiring Meds'), findsOneWidget);
    expect(find.text('Alcohol'), findsNothing);
  });

  testWidgets('shows a no-match message and a way back', (tester) async {
    await pumpHome(tester);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('No match for "zzzz"'), findsOneWidget);
    expect(find.text('0 of 64 items'), findsOneWidget);
  });

  testWidgets('a price query finds every item at that price', (tester) async {
    await pumpHome(tester);

    await tester.enterText(find.byType(TextField), '22.00');
    await tester.pumpAndSettle();

    expect(find.text('3 of 64 items'), findsOneWidget);
    expect(find.text('₱22.00'), findsNWidgets(3));
  });

  testWidgets('a long name does not overflow a narrow row', (tester) async {
    await pumpHome(tester);

    // The longest name in the catalog next to the widest price, on the
    // narrowest screen the app supports.
    await tester.enterText(find.byType(TextField), 'paracetamol');
    await tester.pumpAndSettle();

    expect(find.text('paracetamol 125'), findsOneWidget);
    expect(find.text('₱45.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('adding an item to the order', () {
    // The catalog lists the same name at several prices, so every one of these
    // names the item by its tooltip, which carries both the name and the price
    // that identify it. 'Alcohol' as the initial query keeps the three Alcohol
    // rows on screen; each tooltip is exact, so the patterns stay unique.
    const alcoholQuery = 'Alcohol';

    testWidgets('the row offers an add button while the item is not ordered', (
      tester,
    ) async {
      await pumpHome(tester, query: alcoholQuery);

      expect(find.byTooltip('Add Alcohol'), findsOneWidget);
      expect(order.isEmpty, isTrue);
    });

    testWidgets('tapping it opens the quantity sheet', (tester) async {
      await pumpHome(tester, query: alcoholQuery);

      await tester.tap(find.byTooltip('Add Alcohol'));
      await tester.pumpAndSettle();

      expect(find.text('Add to order'), findsOneWidget);
      expect(find.text('₱65.00'), findsWidgets);
      // Pre-filled with a single unit, the common case at the counter.
      expect(
        tester.widget<TextField>(find.byKey(const Key('quantityField'))).controller?.text,
        '1',
      );
    });

    testWidgets('dismissing the sheet adds nothing', (tester) async {
      await pumpHome(tester, query: alcoholQuery);

      await tester.tap(find.byTooltip('Add Alcohol'));
      await tester.pumpAndSettle();
      // Tapping the barrier above the sheet dismisses it.
      await tester.tapAt(const Offset(180, 60));
      await tester.pumpAndSettle();

      expect(order.isEmpty, isTrue);
      expect(find.byTooltip('Add Alcohol'), findsOneWidget);
    });

    testWidgets('confirming adds one unit and switches the control to remove', (
      tester,
    ) async {
      await pumpHome(tester, query: alcoholQuery);

      await tester.tap(find.byTooltip('Add Alcohol'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to order'));
      await tester.pumpAndSettle();

      expect(order.itemCount, 1);
      expect(order.lines.single.medicine.name, 'Alcohol');
      // The add button is gone, replaced by the quantity pill.
      expect(find.byTooltip('Add Alcohol'), findsNothing);
      expect(find.byTooltip('Remove 1 × Alcohol'), findsOneWidget);
      expect(find.text('×1'), findsOneWidget);
    });

    testWidgets('a typed quantity is what gets added', (tester) async {
      await pumpHome(tester, query: alcoholQuery);

      await tester.tap(find.byTooltip('Add Alcohol'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quantityField')), '7');
      await tester.tap(find.text('Add to order'));
      await tester.pumpAndSettle();

      expect(order.itemCount, 7);
      expect(find.byTooltip('Remove 7 × Alcohol'), findsOneWidget);
    });

    testWidgets('the stepper walks the quantity up and down', (tester) async {
      await pumpHome(tester, query: alcoholQuery);

      await tester.tap(find.byTooltip('Add Alcohol'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('One more'));
      await tester.tap(find.byTooltip('One more'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(const Key('quantityField'))).controller?.text,
        '3',
      );

      await tester.tap(find.byTooltip('One fewer'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(const Key('quantityField'))).controller?.text,
        '2',
      );
    });

    testWidgets('the stepper stops at the cap rather than exceeding it', (
      tester,
    ) async {
      await pumpHome(tester, query: alcoholQuery);

      await tester.tap(find.byTooltip('Add Alcohol'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quantityField')), '99');
      await tester.pumpAndSettle();

      // Disabled rather than inert, so the limit is visible and not a dead tap.
      final more = tester.widget<IconButton>(
        find.byKey(const Key('stepperIncrease')),
      );
      expect(more.onPressed, isNull);

      await tester.enterText(find.byKey(const Key('quantityField')), '1');
      await tester.pumpAndSettle();
      final fewer = tester.widget<IconButton>(
        find.byKey(const Key('stepperDecrease')),
      );
      expect(fewer.onPressed, isNull);
    });

    testWidgets('tapping the quantity control takes the item back out', (
      tester,
    ) async {
      await pumpHome(tester, query: alcoholQuery);

      await tester.tap(find.byTooltip('Add Alcohol'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to order'));
      await tester.pumpAndSettle();
      expect(order.itemCount, 1);

      await tester.tap(find.byTooltip('Remove 1 × Alcohol'));
      await tester.pumpAndSettle();

      expect(order.isEmpty, isTrue);
      // Back to offering an add, so the item can be put in again.
      expect(find.byTooltip('Add Alcohol'), findsOneWidget);
    });

    testWidgets('an added item keeps its row readable on a narrow phone', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.enterText(find.byType(TextField), 'paracetamol');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add paracetamol 125'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to order'));
      await tester.pumpAndSettle();

      // The quantity pill shares the row with the longest name in the catalog.
      expect(find.byTooltip('Remove 1 × paracetamol 125'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the stock line on a row', () {
    Future<void> searchFor(WidgetTester tester, String query) async {
      await pumpHome(tester);
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
    }

    testWidgets('shows a healthy count plainly', (tester) async {
      await searchFor(tester, 'Alcohol med');

      // Seeded at 18, well clear of the low threshold.
      expect(find.text('18 in stock'), findsOneWidget);
      expect(find.textContaining('low'), findsNothing);
    });

    testWidgets('calls a low count out on the row', (tester) async {
      await searchFor(tester, 'meffe');

      // Seeded at 1: the smallest count that is still orderable.
      expect(find.text('1 in stock · low'), findsOneWidget);
    });

    testWidgets('says an out-of-stock item is out', (tester) async {
      await searchFor(tester, 'Alcohol small');

      expect(find.text('Out of stock'), findsOneWidget);
      expect(find.textContaining('in stock'), findsNothing);
    });

    testWidgets('an out-of-stock item cannot be added from the row', (
      tester,
    ) async {
      await searchFor(tester, 'Alcohol small');

      // Kept on the row but greyed out, rather than removed: the item is still a
      // real line in the price list. IconButton builds its Tooltip inside itself,
      // so the button is the tooltip's ancestor.
      final add = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Add Alcohol small'),
          matching: find.byType(IconButton),
        ),
      );
      expect(add.onPressed, isNull);
    });

    testWidgets('the row stays readable with the extra line', (tester) async {
      await searchFor(tester, 'Alcohol med');

      // The longest name in the catalog sharing a row with a price, a stock
      // line and the control.
      expect(find.text('Amox 250 CAP'), findsNothing);
      await searchFor(tester, 'Amox 250');
      expect(find.text('Amox 250 CAP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the longest name is not truncated on a narrow phone', (
      tester,
    ) async {
      await searchFor(tester, 'paracetamol 125');
      // Added as well, so the row is at its widest: name, stock line, price and
      // the quantity pill all competing for 360dp.
      await tester.tap(find.byTooltip('Add paracetamol 125'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to order'));
      await tester.pumpAndSettle();

      // A name too long for the row's two lines does not throw the way a Row
      // does: it quietly ellipsises, and an ellipsised drug name is exactly the
      // failure `tester.takeException()` cannot see.
      //
      // Scoped to the list, because the query in the search field above also
      // reads 'paracetamol 125' and `find.text` would match that too.
      final name = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('paracetamol 125'),
        ),
      );
      // No ellipsis, and no third line: this is the longest name in the catalog
      // sharing a row with a low-stock line, a price and the quantity pill, and
      // it does take two lines to do it -- which is exactly why the name is
      // capped at two rather than left to run.
      expect(name.didExceedMaxLines, isFalse);
      expect(name.size.height, lessThanOrEqualTo(name.preferredLineHeight * 2.5));
      expect(find.byTooltip('Remove 1 × paracetamol 125'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the sheet follows the shelf', () {
    // ALAGAD CAP is seeded at 3, which is the point of all three of these. A
    // query keeps its single row on screen rather than burying it.
    const shelfQuery = 'ALAGAD CAP';

    testWidgets('a low-stock item is capped at what it has', (tester) async {
      await pumpHome(tester, query: shelfQuery);
      // Seeded at 3.
      await tester.tap(find.byTooltip('Add ALAGAD CAP'));
      await tester.pumpAndSettle();

      // The ceiling is explained, not just stated, so a user who cannot type a
      // larger number is told why.
      expect(find.text('Only 3 in stock'), findsOneWidget);
      expect(find.text('Maximum 99 per item'), findsNothing);
    });

    testWidgets('the stepper stops at the shelf, not at the order limit', (
      tester,
    ) async {
      await pumpHome(tester, query: shelfQuery);
      await tester.tap(find.byTooltip('Add ALAGAD CAP'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('One more'));
      await tester.tap(find.byTooltip('One more'));
      await tester.tap(find.byTooltip('One more'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('quantityField')))
            .controller
            ?.text,
        '3',
      );
      final more = tester.widget<IconButton>(
        find.byKey(const Key('stepperIncrease')),
      );
      expect(more.onPressed, isNull);
    });

    testWidgets('an order past the shelf is trimmed on the way in', (
      tester,
    ) async {
      await pumpHome(tester, query: shelfQuery);
      await tester.tap(find.byTooltip('Add ALAGAD CAP'));
      await tester.pumpAndSettle();
      // A typed amount the shelf cannot supply. The field takes it, the order
      // does not: three units end up on the line.
      await tester.enterText(find.byKey(const Key('quantityField')), '40');
      await tester.tap(find.text('Add to order'));
      await tester.pumpAndSettle();

      expect(
        order.quantityOf(
          const MedicineModel(name: 'ALAGAD CAP', priceCentavos: 400, stock: 3),
        ),
        3,
      );
      expect(find.byTooltip('Remove 3 × ALAGAD CAP'), findsOneWidget);
      // 400 * 3, not 400 * 40.
      expect(order.formattedTotal, '₱12.00');
    });

    testWidgets('a healthy item still gets the order limit', (tester) async {
      await pumpHome(tester, query: 'Alcohol');
      await tester.tap(find.byTooltip('Add Alcohol'));
      await tester.pumpAndSettle();

      // Seeded at 240, so the 99-per-item ceiling is the binding one.
      expect(find.text('Maximum 99 per item'), findsOneWidget);
    });
  });
}