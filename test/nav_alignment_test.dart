import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/navigation/app_shell.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/routing/app_router.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_auth_repository.dart';

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

  setUp(() async {
    repository = FakeAuthRepository();
    auth = AuthProvider(repository);
    await auth.ready;
    await auth.login(email: 'a@b.com', password: 'secret');
  });

  tearDown(() {
    auth.dispose();
    repository.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final router = createAppRouter(refreshListenable: auth);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        // Search and Orders watch the order, so tapping those tabs without it
        // throws instead of failing a useful assertion.
        child: ChangeNotifierProvider<OrderProvider>(
          create: (_) => OrderProvider(),
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
      (label: 'Home', marker: find.text('Real Time Inventory')),
      (label: 'Search', marker: find.text('64 items')),
      (label: 'Scan', marker: find.widgetWithText(AppBar, 'Scan')),
      (label: 'Orders', marker: find.text('Nothing in this order yet')),
      (label: 'Profile', marker: find.byTooltip('Sign out')),
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
    // the canary for a sixth tab needing a different layout.
    expect(AppShell.destinations, hasLength(5));
    expect(tester.takeException(), isNull);
  });
}
