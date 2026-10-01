import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/navigation/app_shell.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_repository.dart';
import 'package:pharmaguide/features/search/presentation/providers/medicine_provider.dart';
import 'package:pharmaguide/routing/app_router.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_medicine_store.dart';

/// Guards the one coupling in the app that fails silently.
///
/// [StatefulNavigationShell.goBranch] takes an index, and
/// [AppShell.destinations] is looked up by the same index, so the bar and the
/// router's branch list have to stay in the same order. Insert a destination
/// without inserting a branch in the same position and every tab still taps
/// without throwing — it just shows the wrong screen. These tests walk every
/// index so that mistake fails the suite instead of shipping.
void main() {
  late FakeAuthRepository repository;
  late AuthProvider auth;
  late FakeMedicineStore store;

  setUp(() async {
    repository = FakeAuthRepository();
    auth = AuthProvider(repository);
    await auth.ready;
    await auth.login(email: 'a@b.com', password: 'secret');
    // Seeded with the static price list because one of the markers below is the
    // Search tab's item count, and an empty catalogue would break it for a reason
    // that has nothing to do with navigation.
    store = FakeMedicineStore(initial: const StaticMedicineRepository().all());
  });

  tearDown(() {
    auth.dispose();
    repository.dispose();
    store.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final router = createAppRouter(refreshListenable: auth);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        // Search, Orders, Inventory and Expiring all read one of these, so
        // tapping those destinations without them throws instead of failing a
        // useful assertion.
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
            ChangeNotifierProvider<MedicineProvider>(
              create: (_) => MedicineProvider(auth: auth, storeFor: (_) => store),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildAppTheme(Brightness.light),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every destination selects its own branch', (tester) async {
    await pumpApp(tester);

    // The label and the screen each index is *supposed* to show, asserted
    // absolutely rather than derived from [AppShell.destinations]. Deriving them
    // would be circular: a tab relabelled or moved to the wrong branch would
    // still pass, because the expectation would have moved with it.
    final expected = <({String label, Finder marker})>[
      (label: 'Home', marker: find.text('Expiring Meds')),
      (label: 'Inventory', marker: find.widgetWithText(AppBar, 'Inventory')),
      (label: 'Orders', marker: find.text('Nothing in this order yet')),
      (label: 'Reports', marker: find.widgetWithText(AppBar, 'Reports')),
    ];

    // Catches a bar whose labels were reordered without the branches following.
    expect(
      AppShell.destinations.map((d) => d.label).toList(),
      expected.map((e) => e.label).toList(),
      reason: 'the bar order no longer matches the expected tabs',
    );

    for (var index = 0; index < expected.length; index++) {
      final entry = expected[index];

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(entry.label),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index,
        reason: 'tapping "${entry.label}" should select index $index',
      );
      expect(
        entry.marker,
        findsWidgets,
        reason: 'index $index ("${entry.label}") showed the wrong screen',
      );
    }
  });

  testWidgets('the bar has room for every label on a 360dp phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    // Material 3 caps NavigationBar at five destinations, so this test is also
    // the canary for a sixth tab needing a different layout. The bar is now at
    // four, so the headroom to the cap is larger than it was.
    expect(AppShell.destinations, hasLength(4));
    expect(tester.takeException(), isNull);
  });
}
