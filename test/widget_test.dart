import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmaguide/app.dart';
import 'package:pharmaguide/core/navigation/app_shell.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/auth/data/models/user_model.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/orders/data/repositories/local_order_history_repository.dart';
import 'package:pharmaguide/features/orders/data/repositories/order_history_repository.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_repository.dart';
import 'package:pharmaguide/features/search/presentation/providers/medicine_provider.dart';
import 'package:pharmaguide/features/reports/data/repositories/reports_repository.dart';
import 'package:pharmaguide/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:pharmaguide/features/reports/presentation/providers/reports_provider.dart';
import 'package:pharmaguide/routing/app_router.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_medicine_store.dart';

void main() {
  late FakeAuthRepository repository;
  AuthProvider? provider;

  /// The catalogue every screen in this file reads.
  ///
  /// Seeded with the static price list rather than left empty: a couple of the
  /// routing tests assert that a tab is showing a real list, and an empty
  /// catalogue would let those pass for the wrong reason.
  late FakeMedicineStore store;

  /// Builds the provider *after* any fake behaviour has been configured, since
  /// the AuthProvider starts resolving the session in its constructor.
  AuthProvider createProvider() => provider = AuthProvider(repository);

  setUp(() {
    repository = FakeAuthRepository();
    store = FakeMedicineStore(initial: const StaticMedicineRepository().all());
  });

  tearDown(() {
    provider?.dispose();
    provider = null;
    repository.dispose();
    store.dispose();
  });

  test('starts unknown and settles on unauthenticated', () async {
    final auth = createProvider();
    expect(auth.status, AuthStatus.unknown);

    await auth.ready;

    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.user, isNull);
  });

  // Regression: a throwing refreshUser used to escape _verifySession, leaving
  // _initializing stuck at true so every later auth event was discarded and the
  // app was pinned to the login screen forever.
  test('a failing session refresh still resolves and keeps tracking auth', () async {
    repository.refreshUserError = StateError('network is down');
    final auth = createProvider();

    await auth.ready;

    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.error, contains('network is down'));

    repository.emit(UserModel(id: 'abc', email: 'a@b.com'));
    await Future<void>.delayed(Duration.zero);

    expect(auth.status, AuthStatus.authenticated);
    expect(auth.user?.email, 'a@b.com');
  });

  test('adopts a user that signs in while the session refresh is in flight', () async {
    repository.blockRefresh = true;
    final auth = createProvider();
    final pending = auth.ready;

    repository.currentUser = UserModel(id: 'raced', email: 'race@x.com');
    repository.completeRefresh();
    await pending;

    expect(auth.status, AuthStatus.authenticated);
    expect(auth.user?.id, 'raced');
  });

  test('login sets the user and clears any previous error', () async {
    final auth = createProvider();
    await auth.ready;

    final success = await auth.login(email: 'a@b.com', password: 'secret');

    expect(success, isTrue);
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.error, isNull);
  });

  // Regression: the sheet can call _submit from the keyboard and the button;
  // the second call used to reach Firebase and fail as a duplicate.
  test('concurrent submissions are collapsed into one attempt', () async {
    final auth = createProvider();
    await auth.ready;

    final results = await Future.wait([
      auth.login(email: 'a@b.com', password: 'secret'),
      auth.login(email: 'a@b.com', password: 'secret'),
    ]);

    expect(results, [true, false]);
    expect(repository.loginAttempts, 1);
  });

  test('logout clears the session and the loading flag', () async {
    final auth = createProvider();
    await auth.ready;
    await auth.login(email: 'a@b.com', password: 'secret');
    expect(auth.status, AuthStatus.authenticated);

    final success = await auth.logout();

    expect(success, isTrue);
    expect(auth.isLoading, isFalse);
    expect(auth.status, AuthStatus.unauthenticated);
    expect(repository.logoutCalls, 1);
  });

  // Regression: a failed sign-in used to leave its message on screen after the
  // user signed out, because the error was only cleared on the way *in*.
  test('a failed sign-in error does not survive signing out', () async {
    final auth = createProvider();
    await auth.ready;

    repository.loginError = 'invalid-credential';
    expect(await auth.login(email: 'a@b.com', password: 'bad'), isFalse);
    expect(auth.error, isNotNull);

    repository.emit(null);
    await Future<void>.delayed(Duration.zero);

    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.error, isNull);
  });

  // Regression: notifying a disposed ChangeNotifier throws. An in-flight auth
  // callback can land after teardown, which hot reload makes easy to trigger.
  test('an auth event arriving after dispose does not throw', () async {
    final auth = createProvider();
    await auth.ready;

    auth.dispose();
    // Cleared so tearDown does not dispose the same provider twice.
    provider = null;

    repository.emit(UserModel(id: 'abc', email: 'a@b.com'));
    await Future<void>.delayed(Duration.zero);
  });

/// Puts a [MedicineProvider] over the tree, as main.dart does.
  ///
  /// AppShell reads `syncStatus` from it for the offline banner, so any test that
  /// pumps the real chrome needs one. Backed by the in-memory [store] and the
  /// same fake auth provider, so it settles the same way the app does.
  Widget medicineProvider({required Widget child}) =>
      ChangeNotifierProvider<MedicineProvider>(
        create: (_) => MedicineProvider(
          auth: provider!,
          storeFor: (_) => store,
        ),
        child: child,
      );

  /// Puts the history factory over the tree, as main.dart does.
  ///
  /// The dashboard reads it to build "Today's sales". Backed by the in-memory
  /// repository rather than Firestore: a test has no Firebase app, and the
  /// card only needs history to exist, not to be remote.
  Widget historyFactory({required Widget child}) =>
      Provider<OrderHistoryRepositoryFactory>.value(
        value: (_) => LocalOrderHistoryRepository(),
        child: child,
      );

  Future<void> pumpApp(WidgetTester tester, AuthProvider auth) async {
    final router = createAppRouter(refreshListenable: auth);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        // The Search and Orders branches both watch OrderProvider, so this has
        // to sit above the router here exactly as main.dart does. Without it
        // those two branches throw ProviderNotFoundException, which would look
        // like a routing bug rather than a missing test provider.
        child: ChangeNotifierProvider<OrderProvider>(
          create: (_) => OrderProvider(),
          child: medicineProvider(
            child: historyFactory(
              child: MaterialApp.router(
                routerConfig: router,
                theme: buildAppTheme(Brightness.light),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pumps the real [App], rather than the MaterialApp [pumpApp] builds by
  /// hand, so AppShell, the content panel and the theme are actually in the
  /// tree. Anything asserting on screen geometry needs the real chrome.
  Future<void> pumpRealApp(
    WidgetTester tester, {
    required AuthProvider auth,
  }) async {
    final router = createAppRouter(refreshListenable: auth);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      // The router redirects to the auth landing screen, which watches
      // AuthProvider, so it has to sit above the router as it does in
      // main.dart's MultiProvider.
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: ChangeNotifierProvider<OrderProvider>(
          create: (_) => OrderProvider(),
          child: medicineProvider(
            child: historyFactory(
              child: Provider<ReportsRepository>(
                create: (ctx) => ReportsRepositoryImpl(
                  medicineProvider: ctx.read<MedicineProvider>(),
                  historyFactory: () => ctx.read<OrderHistoryRepositoryFactory>()(
                    ctx.read<AuthProvider>().user?.id ?? '',
                  ),
                ),
                child: ChangeNotifierProvider<ReportsProvider>(
                  create: (ctx) => ReportsProvider(
                    repository: ctx.read<ReportsRepository>(),
                  ),
                  child: Provider<GoRouter>.value(value: router, child: const App()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('routing', () {
    testWidgets('an unauthenticated user lands on the login screen', (
      tester,
    ) async {
      final auth = createProvider();
      await auth.ready;

      await pumpApp(tester, auth);
      await tester.pumpAndSettle();

      expect(find.text('Welcome to'), findsOneWidget);
    });

    testWidgets('an authenticated user lands on the home tab', (
      tester,
    ) async {
      repository.currentUser = UserModel(id: '1', name: 'Ada', email: 'a@b.com');
      final auth = createProvider();
      await auth.ready;
      expect(auth.status, AuthStatus.authenticated);

      await pumpApp(tester, auth);
      await tester.pumpAndSettle();

      expect(find.text("Today's sales"), findsOneWidget);
      expect(find.text('Welcome to'), findsNothing);
    });

// Regression: the home screen previously had no way to sign out. Sign-out
    // now lives on the Profile page pushed from a Home tile, so the user has to
    // navigate there first.
    testWidgets('signing out from the profile page returns to login', (
      tester,
    ) async {
      final auth = createProvider();
      await auth.ready;
      await auth.login(email: 'a@b.com', password: 'secret');

      await pumpApp(tester, auth);
      await tester.pumpAndSettle();
      expect(find.text("Today's sales"), findsOneWidget);

      // Profile is now an icon button in the AppBar
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();

      // Sign-out is a full-width outlined button at the foot of the page, not
      // an AppBar action, so it is found by its label rather than by tooltip.
      // It also sits just past the fold on the test viewport, and a ListView
      // builds lazily, so the widget is not in the tree until the page is
      // scrolled: scrolling first is what makes the finder resolve.
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, 'Sign out'),
        200,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to'), findsOneWidget);
    });

testWidgets('the bottom bar switches between the tabs', (tester) async {
      final auth = createProvider();
      await auth.ready;
      await auth.login(email: 'a@b.com', password: 'secret');

      await pumpApp(tester, auth);
      await tester.pumpAndSettle();

      // Tapped by label rather than icon: the selected destination renders its
      // filled icon and the unselected one its outlined icon, so an icon lookup
      // only resolves while that tab happens to be inactive.
      Finder tab(String label) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      int selectedIndex() =>
          tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

      await tester.tap(tab('Inventory'));
      await tester.pumpAndSettle();
      expect(selectedIndex(), 1);
      expect(find.widgetWithText(AppBar, 'Inventory'), findsOneWidget);

      await tester.tap(tab('Orders'));
      await tester.pumpAndSettle();
      expect(selectedIndex(), 2);
      expect(find.text('No all orders right now.'), findsOneWidget);

      await tester.tap(tab('Reports'));
      await tester.pumpAndSettle();
      expect(selectedIndex(), 3);
      expect(find.widgetWithText(AppBar, 'Sales & Analytics Report'), findsOneWidget);

      await tester.tap(tab('Home'));
      await tester.pumpAndSettle();
      expect(selectedIndex(), 0);
      expect(find.text("Today's sales"), findsOneWidget);
    });

    testWidgets('orders sits at index 2 and reports at 3', (
      tester,
    ) async {
      final auth = createProvider();
      await auth.ready;
      await auth.login(email: 'a@b.com', password: 'secret');

      await pumpApp(tester, auth);
      await tester.pumpAndSettle();

      Finder tab(String label) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      int selectedIndex() =>
          tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

      await tester.tap(tab('Orders'));
      await tester.pumpAndSettle();
      expect(find.text('No all orders right now.'), findsOneWidget);
      expect(selectedIndex(), 2);

      // The regression this guards: inserting or removing a branch shifts every
      // later one, so the bar would highlight one tab while showing another.
      await tester.tap(tab('Reports'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Sales & Analytics Report'), findsOneWidget);
      expect(selectedIndex(), 3);
    });

    testWidgets('the bar shows four destinations in order on a 360dp phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final auth = createProvider();
      await auth.ready;
      await auth.login(email: 'a@b.com', password: 'secret');

      await pumpApp(tester, auth);
      await tester.pumpAndSettle();

      // Four slots across 360dp is 90dp each, and "Inventory" is the longest
      // label, so this proves the bar does not clip on the narrowest screen the
      // app is expected to run on.
      expect(AppShell.destinations, hasLength(4));
      expect(
        AppShell.destinations.map((d) => d.label),
        ['Home', 'Inventory', 'Orders', 'Reports'],
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

testWidgets('a home action opens a child page and back returns home', (
      tester,
    ) async {
      final auth = createProvider();
      await auth.ready;
      await auth.login(email: 'a@b.com', password: 'secret');

      await pumpApp(tester, auth);
      await tester.pumpAndSettle();

      // The expiring chip is a child of the Home branch, so it pushes rather than
      // switch tabs: Home stays selected and a back arrow appears.
      await tester.tap(find.text('Expiring soon'));
      await tester.pumpAndSettle();
      expect(find.text('Expiring Meds'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
        reason: 'pushing a child page must not switch away from Home',
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text("Today's sales"), findsOneWidget);

      // The scan button beside the search field also pushes a child page.
      await tester.tap(find.byTooltip('Scan product name'));
      await tester.pumpAndSettle();
      expect(find.text('Scan'), findsOneWidget);
    });
  });

  group('app bar titles', () {
    // Only the five tab roots centre their titles. The three pages pushed from
    // a Home tile stay leading-aligned, so both halves are asserted: a
    // change to AppBarTheme.centerTitle would centre all eight and neither
    // mistake throws.

    /// The title inside the AppBar, excluding the bottom bar's identically
    /// labelled destination.
    Finder appBarTitle(String label) => find.descendant(
      of: find.byType(AppBar),
      matching: find.text(label),
    );

    testWidgets('the four tab titles sit on the centreline', (tester) async {
      final auth = createProvider();
      await auth.login(email: 'a@b.com', password: 'secret');
      await pumpRealApp(tester, auth: auth);

      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final centreline = width / 2;

      // Home tab has a custom title "Wilma Pharmacy's"; the Reports screen
      // names its own rather than reusing the tab label.
      final expectedTitles = {
        'Home': "Wilma Pharmacy's",
        'Inventory': 'Inventory',
        'Orders': 'Orders',
        'Reports': 'Reports & Analytics',
      };

      for (final label in AppShell.destinations.map((d) => d.label)) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();

        final expectedTitle = expectedTitles[label] ?? label;
        expect(appBarTitle(expectedTitle), findsOneWidget);
        final centre = tester.getCenter(appBarTitle(expectedTitle)).dx;
        // The panel's side margins are symmetric, so a title centred in its
        // AppBar lands on the screen's centreline. One logical pixel of slack
        // for sub-pixel layout rounding.
        expect(
          (centre - centreline).abs(),
          lessThan(1.0),
          reason: 'the "$label" title should be centred, not leading-aligned',
        );
      }
    });

    testWidgets('pushed child pages keep a leading-aligned title', (
      tester,
    ) async {
      final auth = createProvider();
      await auth.login(email: 'a@b.com', password: 'secret');
      await pumpRealApp(tester, auth: auth);

      await tester.tap(find.text('Expiring soon'));
      await tester.pumpAndSettle();

      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final centre = tester.getCenter(appBarTitle('Expiring Meds')).dx;

      // Not a pixel-exact bound on purpose: the point is that it sits well
      // left of the middle, which is what a leading-aligned title does.
      expect(
        centre,
        lessThan(width / 2 - 50),
        reason: 'child pages are scoped out of the centring on purpose',
      );
    });
  });

  group('login sheet', () {
    testWidgets('landing shows the buttons and the login sheet opens', (
      tester,
    ) async {
      final auth = createProvider();
      await auth.ready;

      await pumpApp(tester, auth);
      await tester.pumpAndSettle();

      expect(find.text('Welcome to'), findsOneWidget);
      expect(find.text("Wilma\nPharmacy's"), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Signup'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('an invalid email is rejected by the form, not the repository', (
      tester,
    ) async {
      final auth = createProvider();
      await auth.ready;

      await pumpApp(tester, auth);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(repository.loginAttempts, 0);
    });

    testWidgets('a successful login pops the sheet and opens home', (
      tester,
    ) async {
      final auth = createProvider();
      await auth.ready;

      await pumpApp(tester, auth);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsNothing);
      expect(find.text("Today's sales"), findsOneWidget);
      expect(repository.loginAttempts, 1);
    });
  });
}
