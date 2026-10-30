import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmaguide/features/auth/data/repositories/offline_pin.dart';
import 'package:pharmaguide/features/auth/data/repositories/offline_session.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/auth/presentation/screens/offline_pin_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_auth_repository.dart';

/// A [StoredOfflinePinStore] over a mutable string, so the hashing and the
/// stored format are exercised without a preferences plugin.
({StoredOfflinePinStore store, String? Function() value}) buildStore() {
  String? value;
  final store = StoredOfflinePinStore(
    readStorage: () async => value,
    writeStorage: (next) async => value = next,
  );
  return (store: store, value: () => value);
}

void main() {
  group('the stored PIN', () {
    test('is not written in plain text', () async {
      final harness = buildStore();

      await harness.store.save('4821');

      final stored = harness.value();
      expect(stored, isNotNull);
      expect(stored, isNot(contains('4821')));
      expect(stored, startsWith(r'v1$'));
      // v1, salt, hash.
      expect(stored!.split(r'$'), hasLength(3));
    });

    test('matches only the PIN that was set', () async {
      final harness = buildStore();
      await harness.store.save('4821');

      expect(await harness.store.hasPin(), isTrue);
      expect(await harness.store.matches('4821'), isTrue);
      expect(await harness.store.matches('4822'), isFalse);
      expect(await harness.store.matches('482'), isFalse);
      expect(await harness.store.matches('48211'), isFalse);
    });

    test('salts each write, so two saves of the same PIN differ', () async {
      final harness = buildStore();
      await harness.store.save('1111');
      final first = harness.value();
      await harness.store.save('1111');

      expect(harness.value(), isNot(first));
      // Both still match: the salt is part of the value, not of the PIN.
      expect(await harness.store.matches('1111'), isTrue);
    });

    test('is gone after clear, and a cleared install reports no PIN', () async {
      final harness = buildStore();
      await harness.store.save('1234');
      await harness.store.clear();

      expect(await harness.store.hasPin(), isFalse);
      expect(await harness.store.matches('1234'), isFalse);
    });

    test('rejects anything that is not four digits', () async {
      final harness = buildStore();

      for (final bad in ['', '123', '12345', 'abcd', '12 4']) {
        await expectLater(
          harness.store.save(bad),
          throwsArgumentError,
          reason: '"$bad" should not be accepted as a PIN',
        );
      }
      expect(await harness.store.hasPin(), isFalse);
    });

    test('treats an unreadable stored value as no PIN rather than a wrong one',
        () async {
      final harness = buildStore();
      // Written by a future version, or corrupted on disk.
      await harness.store.save('1234');
      final corrupt = StoredOfflinePinStore(
        readStorage: () async => 'v9\$whatever',
        writeStorage: (_) async {},
      );

      expect(await corrupt.hasPin(), isTrue);
      expect(await corrupt.matches('1234'), isFalse);
      expect(harness.value(), isNotNull);
    });

    test('an empty stored value counts as no PIN', () async {
      final store = StoredOfflinePinStore(
        readStorage: () async => '',
        writeStorage: (_) async {},
      );

      expect(await store.hasPin(), isFalse);
      expect(await store.matches('1234'), isFalse);
    });
  });

  group('the provider', () {
    late FakeAuthRepository repository;
    late InMemoryOfflineSession session;
    late InMemoryOfflinePinStore pins;
    AuthProvider? provider;

    setUp(() {
      repository = FakeAuthRepository();
      session = InMemoryOfflineSession();
      pins = InMemoryOfflinePinStore();
    });

    tearDown(() {
      provider?.dispose();
      provider = null;
      repository.dispose();
    });

    AuthProvider createProvider() => provider = AuthProvider(
          repository,
          offlineSession: session,
          pinStore: pins,
        );

    test('setting a PIN stores it and unlocks', () async {
      final auth = createProvider();
      await auth.ready;

      await auth.setOfflinePin('4821');

      expect(await auth.hasOfflinePin, isTrue);
      expect(pins.pin, '4821');
      expect(auth.offlineUnlocked, isTrue);
    });

    test('unlocking with the right PIN clears the lock', () async {
      pins.pin = '4821';
      session = InMemoryOfflineSession(true);
      final auth = createProvider();
      await auth.ready;

      expect(auth.offlineLocked, isTrue);

      expect(await auth.unlockOffline('4821'), isTrue);
      expect(auth.offlineLocked, isFalse);
      expect(auth.offlineUnlocked, isTrue);
    });

    test('a wrong PIN leaves the session locked and counts the attempt',
        () async {
      pins.pin = '4821';
      session = InMemoryOfflineSession(true);
      final auth = createProvider();
      await auth.ready;

      expect(await auth.unlockOffline('0000'), isFalse);

      expect(auth.offlineLocked, isTrue);
      expect(auth.failedPinAttempts, 1);
      expect(auth.error, 'Wrong PIN.');
    });

    test('five wrong PINs start a cooldown that even the right PIN waits out',
        () async {
      pins.pin = '4821';
      session = InMemoryOfflineSession(true);
      final auth = createProvider();
      await auth.ready;

      for (var i = 0; i < AuthProvider.maxPinAttempts; i++) {
        expect(await auth.unlockOffline('0000'), isFalse);
      }

      expect(auth.pinCooldownRemaining, greaterThan(Duration.zero));
      // The right PIN is refused outright during the cooldown rather than
      // resetting it.
      expect(await auth.unlockOffline('4821'), isFalse);
      expect(auth.offlineLocked, isTrue);
    });

    test('a cold start with a PIN on file boots locked', () async {
      pins.pin = '4821';
      session = InMemoryOfflineSession(true);

      final auth = createProvider();
      await auth.ready;

      expect(auth.status, AuthStatus.offline);
      expect(auth.offlineLocked, isTrue);
      expect(auth.user?.id, AuthProvider.offlineUserId);
    });

    test('a cold start with no PIN keeps the old unlocked behaviour', () async {
      session = InMemoryOfflineSession(true);

      final auth = createProvider();
      await auth.ready;

      expect(auth.status, AuthStatus.offline);
      expect(auth.offlineLocked, isFalse);
    });

    test('entering offline mode is always unlocked', () async {
      pins.pin = '4821';
      final auth = createProvider();
      await auth.ready;

      await auth.enterOfflineMode();

      expect(auth.status, AuthStatus.offline);
      expect(auth.offlineLocked, isFalse);
    });

    test('leaving offline mode keeps the PIN for next time', () async {
      pins.pin = '4821';
      final auth = createProvider();
      await auth.ready;
      await auth.enterOfflineMode();

      await auth.exitOfflineMode();

      expect(auth.status, AuthStatus.unauthenticated);
      expect(pins.pin, '4821');
    });

    test('locking keeps the mode and role, only closing the lock', () async {
      pins.pin = '4821';
      final auth = createProvider();
      await auth.ready;
      await auth.enterOfflineMode();

      auth.lockOffline();

      expect(auth.status, AuthStatus.offline);
      expect(auth.offlineLocked, isTrue);
      expect(auth.user?.id, AuthProvider.offlineUserId);
    });

    test('clearing the PIN returns the install to first-run', () async {
      pins.pin = '4821';
      final auth = createProvider();
      await auth.ready;

      await auth.clearOfflinePin();

      expect(await auth.hasOfflinePin, isFalse);
      expect(pins.pin, isNull);
    });
  });

  group('the PIN screen', () {
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

    Future<AuthProvider> pumpPin(
      WidgetTester tester, {
      required OfflinePinMode mode,
      bool offline = false,
    }) async {
      // Tall enough for the whole pad: on the default 800x600 surface the last
      // row and the footer fall outside the viewport, so taps miss them.
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      provider = AuthProvider(
        repository,
        offlineSession: InMemoryOfflineSession(offline),
        pinStore: pins,
      );
      final auth = provider!;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(home: OfflinePinScreen(mode: mode)),
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

    testWidgets('create asks twice, stores the PIN and starts offline mode', (
      tester,
    ) async {
      final auth = await pumpPin(tester, mode: OfflinePinMode.create);

      expect(find.text('Choose a 4-digit PIN'), findsOneWidget);
      await typePin(tester, '4821');

      expect(find.text('Confirm your PIN'), findsOneWidget);
      await typePin(tester, '4821');

      expect(pins.pin, '4821');
      expect(auth.status, AuthStatus.offline);
    });

    testWidgets('a mismatched confirmation starts over', (tester) async {
      final auth = await pumpPin(tester, mode: OfflinePinMode.create);

      await typePin(tester, '4821');
      await typePin(tester, '1111');

      expect(find.text("Those PINs don't match. Start again."), findsOneWidget);
      expect(find.text('Choose a 4-digit PIN'), findsOneWidget);
      expect(pins.pin, isNull);
      expect(auth.status, AuthStatus.unauthenticated);
    });

    testWidgets('unlock accepts the stored PIN', (tester) async {
      pins.pin = '4821';
      final auth = await pumpPin(
        tester,
        mode: OfflinePinMode.unlock,
        offline: true,
      );

      expect(auth.offlineLocked, isTrue);
      await typePin(tester, '4821');

      expect(auth.offlineLocked, isFalse);
    });

    testWidgets('unlock from the landing screen starts offline mode', (
      tester,
    ) async {
      // No session yet: this is "Continue Offline" with a PIN on file, not a
      // cold start that booted locked.
      pins.pin = '4821';
      final auth = await pumpPin(tester, mode: OfflinePinMode.unlock);

      expect(auth.status, AuthStatus.unauthenticated);
      await typePin(tester, '4821');

      expect(auth.status, AuthStatus.offline);
      expect(auth.offlineUnlocked, isTrue);
    });

    testWidgets('unlock names the tries left after a wrong PIN', (tester) async {
      pins.pin = '4821';
      final auth = await pumpPin(
        tester,
        mode: OfflinePinMode.unlock,
        offline: true,
      );

      await typePin(tester, '0000');

      expect(find.text('Wrong PIN — 4 tries left.'), findsOneWidget);
      expect(auth.offlineLocked, isTrue);
    });

    testWidgets('sign in instead ends offline mode and leaves the pad', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      pins.pin = '4821';
      provider = AuthProvider(
        repository,
        offlineSession: InMemoryOfflineSession(true),
        pinStore: pins,
      );
      final auth = provider!;
      await auth.ready;

      // This button navigates, so the pad is mounted under a router the way the
      // app mounts it. A cold start has no stack to pop, so it goes to login.
      final router = GoRouter(
        initialLocation: '/offline-lock',
        routes: [
          GoRoute(
            path: '/offline-lock',
            builder: (context, state) =>
                const OfflinePinScreen(mode: OfflinePinMode.unlock),
          ),
          GoRoute(
            path: '/login',
            name: 'login',
            builder: (context, state) =>
                const Scaffold(body: Text('login screen')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in instead'));
      await tester.pumpAndSettle();

      expect(auth.status, AuthStatus.unauthenticated);
      expect(find.text('login screen'), findsOneWidget);
    });
  });
}
