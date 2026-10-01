import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmaguide/app.dart';
import 'package:pharmaguide/core/navigation/app_shell.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/core/widgets/app_background.dart';
import 'package:pharmaguide/core/widgets/content_panel.dart';
import 'package:pharmaguide/features/auth/data/models/user_model.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/auth/presentation/screens/auth_landing_screen.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_repository.dart';
import 'package:pharmaguide/features/search/presentation/providers/medicine_provider.dart';
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
            child: MaterialApp.router(
              routerConfig: router,
              theme: buildAppTheme(Brightness.light),
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
            child: Provider<GoRouter>.value(value: router, child: const App()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('app background', () {
    // The artwork is mounted by AppShell, so it covers the signed-in area and
    // not the login route. Both halves are asserted below, because a
    // background applied one level too high looks fine on the tabs and wrong
    // on login, and neither mistake throws.

    test('the theme lets the background show through', () {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(brightness);
        final label = brightness.name;

        // Each screen owns its own Scaffold, so an opaque colour here would
        // hide bgtheme.png completely and nothing else would look wrong.
        expect(
          theme.scaffoldBackgroundColor,
          Colors.transparent,
          reason: '$label scaffolds would cover the background',
        );
        expect(
          theme.appBarTheme.backgroundColor,
          Colors.transparent,
          reason: '$label app bars would cover the background',
        );
        expect(
          theme.appBarTheme.scrolledUnderElevation,
          0,
          reason: '$label app bars would tint the background when scrolled',
        );
      }
    });

    test('the nav bar is opaque so its destinations stay visible', () {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(brightness);
        final label = brightness.name;

        // The artwork is light, and unselected destinations are low-contrast
        // grey. A transparent bar left all five effectively invisible, so the
        // bar is the one surface that must not inherit transparency.
        expect(
          theme.navigationBarTheme.backgroundColor,
          isNot(Colors.transparent),
          reason: '$label nav bar icons would vanish into the artwork',
        );
        expect(
          theme.navigationBarTheme.elevation,
          greaterThan(0),
          reason: '$label nav bar needs lift to separate it from the artwork',
        );
        expect(
          theme.navigationBarTheme.labelBehavior,
          NavigationDestinationLabelBehavior.alwaysShow,
          reason: '$label nav bar must not drop labels on short viewports',
        );
      }
    });

    testWidgets('app mode is pinned to light for the light background', (
      tester,
    ) async {
      final auth = createProvider();
      await pumpRealApp(tester, auth: auth);

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      // Left following the system, the dark theme's near-white text would sit
      // on the 88% luminance artwork and be unreadable.
      expect(app.themeMode, ThemeMode.light);
      expect(app.darkTheme!.colorScheme.onSurface.computeLuminance(),
          greaterThan(0.5));
    });

    testWidgets('the login screen has no background image', (tester) async {
      await pumpRealApp(tester, auth: createProvider());

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(
        find.byType(AppBackground),
        findsNothing,
        reason: 'the login route sits outside the shell, so it must not be '
            'backed by the artwork',
      );
    });

    testWidgets('the login screen still paints an opaque surface', (
      tester,
    ) async {
      await pumpRealApp(tester, auth: createProvider());

      // The theme's scaffold background is transparent so the shell's artwork
      // can show through. Nothing is behind the login route, so an inherited
      // transparent scaffold would show the raw window background here.
      final scaffold = tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(AuthLandingScreen),
          matching: find.byType(Scaffold),
        ),
      );
      expect(scaffold.backgroundColor, isNot(Colors.transparent));
      expect(scaffold.backgroundColor?.computeLuminance(), greaterThan(0.5));
    });

    testWidgets('the signed-in tabs share one background from the shell', (
      tester,
    ) async {
      final auth = createProvider();
      await auth.login(email: 'a@b.com', password: 'secret');
      await pumpRealApp(tester, auth: auth);

      expect(find.byType(AppBackground), findsOneWidget);

      // Still exactly one after switching tabs: the artwork belongs to the
      // shell, not to a tab, so it must not be rebuilt or duplicated per tab.
      for (final label in AppShell.destinations.map((d) => d.label)) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(AppBackground),
          findsOneWidget,
          reason: 'tab "$label" should not have its own background',
        );
      }
    });

    testWidgets('tab content is raised on a panel inside the artwork', (
      tester,
    ) async {
      final auth = createProvider();
      await auth.login(email: 'a@b.com', password: 'secret');
      await pumpRealApp(tester, auth: auth);

      // The artwork stays; only the content stopped sitting directly on it.
      expect(find.byType(AppBackground), findsOneWidget);
      expect(find.byType(ContentPanel), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ContentPanel),
          matching: find.byType(Scaffold),
        ),
        findsWidgets,
      );
      // Chrome stays outside the panel so the bar keeps its own surface.
      expect(
        find.descendant(
          of: find.byType(ContentPanel),
          matching: find.byType(NavigationBar),
        ),
        findsNothing,
      );

      final panel = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ContentPanel),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = panel.decoration! as BoxDecoration;
      // Translucent, but only just: below about 0.85 the artwork starts
      // competing with body text, and fully opaque would hide it entirely.
      expect(decoration.color!.a, greaterThanOrEqualTo(0.85));
      expect(decoration.color!.a, lessThanOrEqualTo(0.95));
      expect(decoration.boxShadow, isNotEmpty);
    });

    testWidgets('tab content clears the status bar inset', (tester) async {
      // The window draws under the status bar, so the shell has to inset itself.
      // 24dp is this device's bar; what matters is that the inset is honoured
      // at all, and honoured exactly once.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 600);
      tester.view.padding = const FakeViewPadding(top: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.reset);

      final auth = createProvider();
      await auth.login(email: 'a@b.com', password: 'secret');
      await pumpRealApp(tester, auth: auth);

      // Without the shell's SafeArea the panel's own 14dp margin put its top
      // edge, corners and shadow underneath the clock, signal and battery.
      final panelTop = tester.getTopLeft(find.byType(ContentPanel)).dy;
      expect(
        panelTop,
        greaterThanOrEqualTo(24),
        reason: 'the panel must start below the status bar',
      );
      // Exactly one inset. If the shell and the tab AppBar both added it, this
      // would be 48 and the content would sit in a 24dp empty gap.
      expect(
        panelTop,
        lessThan(24 + 14),
        reason: 'the status bar inset must be consumed once, not twice',
      );

      // The title stays clear of the bar as well. Scoped to the AppBar, since
      // "Home" is also the bottom bar's label for the same tab.
      expect(
        tester
            .getTopLeft(
              find.descendant(
                of: find.byType(AppBar),
                matching: find.text('Home'),
              ),
            )
            .dy,
        greaterThanOrEqualTo(24),
      );
    });

    testWidgets('the background stacks the image behind its child', (
      tester,
    ) async {
      await tester.pumpWidget(
        // In the app this sits under MaterialApp, which supplies
        // Directionality. Pumped bare, the Stack would have no text direction
        // to resolve its default alignment against.
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppBackground(
            // A test asset bundle has no manifest, so a real AssetImage would
            // fail to resolve. This stands in for it.
            image: const AssetImage('assets/images/baseIcon.png'),
            child: const Text('on top'),
          ),
        ),
      );
      await tester.pump();

      final stack = tester.widget<Stack>(find.byType(Stack));
      expect(stack.fit, StackFit.expand);

      // Decoration first, app second: a later child paints on top, so the
      // reversed order would hide the app instead of the image.
      expect(stack.children.first, isA<Image>());
      expect(stack.children.last, isA<Text>());
      expect(find.text('on top'), findsOneWidget);
    });
  });

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

      expect(find.text('Expiring Meds'), findsOneWidget);
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
      expect(find.text('Expiring Meds'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sign out'));
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
      expect(find.text('Live stock levels across the pharmacy'), findsOneWidget);

      await tester.tap(tab('Orders'));
      await tester.pumpAndSettle();
      expect(selectedIndex(), 2);
      expect(find.text('Nothing in this order yet'), findsOneWidget);

      await tester.tap(tab('Reports'));
      await tester.pumpAndSettle();
      expect(selectedIndex(), 3);
      expect(find.widgetWithText(AppBar, 'Reports'), findsOneWidget);

      await tester.tap(tab('Home'));
      await tester.pumpAndSettle();
      expect(selectedIndex(), 0);
      expect(find.text('Expiring Meds'), findsOneWidget);
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
      expect(find.text('Nothing in this order yet'), findsOneWidget);
      expect(selectedIndex(), 2);

      // The regression this guards: inserting or removing a branch shifts every
      // later one, so the bar would highlight one tab while showing another.
      await tester.tap(tab('Reports'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Reports'), findsOneWidget);
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

testWidgets('a home tile pushes a child page and back returns home', (
      tester,
    ) async {
      final auth = createProvider();
      await auth.ready;
      await auth.login(email: 'a@b.com', password: 'secret');

      await pumpApp(tester, auth);
      await tester.pumpAndSettle();

      // The tiles are children of the Home branch, so they push rather than
      // switch tabs: Home stays selected and a back arrow appears.
      await tester.tap(find.text('Expiring Meds'));
      await tester.pumpAndSettle();
      expect(find.text('Expiring Meds'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
        reason: 'pushing a child page must not switch away from Home',
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Expiring Meds'), findsOneWidget);

      await tester.tap(find.text('Scan Prescription'));
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

      for (final label in AppShell.destinations.map((d) => d.label)) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();

        expect(appBarTitle(label), findsOneWidget);
        final centre = tester.getCenter(appBarTitle(label)).dx;
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

      await tester.tap(find.text('Expiring Meds'));
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
      expect(find.text('Expiring Meds'), findsOneWidget);
      expect(repository.loginAttempts, 1);
    });
  });
}
