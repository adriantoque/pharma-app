import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmaguide/features/auth/data/repositories/offline_pin.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/auth/presentation/screens/offline_pin_screen.dart';
import 'package:pharmaguide/features/profile/presentation/screens/profile_screen.dart';
import 'package:provider/provider.dart';

import '../../helpers/fake_auth_repository.dart';

/// The profile's route subtree, with the same names the real router gives the
/// profile and its offline-PIN page, so the tile's `pushNamed` resolves.
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/home/profile',
    routes: [
      GoRoute(
        path: '/home',
        // Never shown: the profile is the initial location. go_router only
        // needs a builder so the branch is a page.
        builder: (context, state) => const Scaffold(body: Text('home')),
        routes: [
          GoRoute(
            path: 'profile',
            name: 'home-profile',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'offline-pin',
                name: 'home-profile-offline-pin',
                builder: (context, state) => OfflinePinScreen(
                  mode: OfflinePinMode.update,
                  onSaved: () => context.pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  late FakeAuthRepository repository;
  late InMemoryOfflinePinStore pins;
  AuthProvider? provider;

  setUp(() {
    repository = FakeAuthRepository();
    pins = InMemoryOfflinePinStore();
  });

  tearDown(() {
    provider?.dispose();
    provider = null;
    repository.dispose();
  });

  Future<AuthProvider> pumpProfile(WidgetTester tester) async {
    // Tall enough for the whole PIN pad and the whole profile list.
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = provider = AuthProvider(repository, pinStore: pins);
    await auth.ready;
    final router = buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.byKey(Key('pinKey$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('the profile offers the offline PIN and starts from "Not set"', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text('Offline PIN'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('setting a PIN from the profile stores it and returns', (
    tester,
  ) async {
    final auth = await pumpProfile(tester);

    await tester.tap(find.text('Offline PIN'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a 4-digit PIN'), findsOneWidget);

    await typePin(tester, '4821');
    expect(find.text('Confirm your PIN'), findsOneWidget);
    await typePin(tester, '4821');

    // Stored, but offline mode was not started: this is a settings change, not
    // the "Continue Offline" flow.
    expect(pins.pin, '4821');
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.isOffline, isFalse);

    // Back on the profile, with the tile reporting the new state.
    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text('Set'), findsOneWidget);
    expect(find.text('Offline PIN saved.'), findsOneWidget);
  });

  testWidgets('a mismatched confirmation stores nothing and stays on the pad', (
    tester,
  ) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Offline PIN'));
    await tester.pumpAndSettle();

    await typePin(tester, '4821');
    await typePin(tester, '1111');

    expect(find.text("Those PINs don't match. Start again."), findsOneWidget);
    expect(find.text('Choose a 4-digit PIN'), findsOneWidget);
    expect(pins.pin, isNull);
  });

  testWidgets('cancelling the pad leaves the PIN as it was', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Offline PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    expect(pins.pin, isNull);
  });
}
