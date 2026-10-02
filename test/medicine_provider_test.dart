import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/auth/data/models/user_model.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_store.dart';
import 'package:pharmaguide/features/search/presentation/providers/medicine_provider.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_medicine_store.dart';

/// Covers the provider's own behaviour: which account's catalogue is on screen,
/// what happens while the first read is outstanding, and that a count typed at
/// the counter is painted before the write is confirmed.
void main() {
  const amox = MedicineModel(name: 'Amox', priceCentavos: 400, stock: null);
  const cetirizine = MedicineModel(
    name: 'Cetirizine',
    priceCentavos: 300,
    stock: 12,
    aliases: ['ceterizine'],
  );

  late FakeAuthRepository authRepository;
  late AuthProvider auth;

  /// One store per account, so a test can tell whose catalogue is showing.
  final stores = <String, FakeMedicineStore>{};

  /// The uids a store was built for, in order.
  final requestedFor = <String>[];

  /// Emits an auth state for [uid], as Firebase does on a real session change.
  Future<void> signInAs(String uid) async {
    authRepository.emit(
      UserModel(id: uid, name: uid, email: '$uid@example.com'),
    );
    // The provider subscribes and the first read arrives as a stream event, so
    // the event loop has to run before anything is on screen.
    await pumpEventQueue();
  }

  MedicineStore storeFor(String uid) {
    requestedFor.add(uid);
    return stores.putIfAbsent(uid, () => FakeMedicineStore());
  }

  /// Signs [uid] in and returns a provider reading that account's catalogue.
  ///
  /// Goes through the repository's stream rather than `login`, because that
  /// always signs in as id `1` and these tests need to tell two accounts apart.
  Future<MedicineProvider> signedIn(
    String uid, {
    List<MedicineModel> catalogue = const [],
  }) async {
    await auth.ready;
    stores[uid] = FakeMedicineStore(initial: catalogue);
    final provider = MedicineProvider(auth: auth, storeFor: storeFor);
    addTearDown(provider.dispose);
    await signInAs(uid);
    return provider;
  }

  setUp(() {
    stores.clear();
    requestedFor.clear();
    authRepository = FakeAuthRepository();
    auth = AuthProvider(authRepository);
  });

  tearDown(() {
    auth.dispose();
    authRepository.dispose();
    for (final store in stores.values) {
      store.dispose();
    }
  });

  group('which account the catalogue belongs to', () {
    test('reads the signed-in user\'s list', () async {
      final provider = await signedIn('u1', catalogue: [amox, cetirizine]);

      expect(provider.all(), [amox, cetirizine]);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    });

    test('has nothing to show before anyone signs in', () async {
      await auth.ready;
      final provider = MedicineProvider(auth: auth, storeFor: storeFor);
      addTearDown(provider.dispose);
      await pumpEventQueue();

      expect(provider.isEmpty, isTrue);
      expect(
        requestedFor,
        isEmpty,
        reason: 'no account, so no catalogue to read',
      );
    });

    test('empties itself on sign-out', () async {
      final provider = await signedIn('u1', catalogue: [amox]);

      await auth.logout();
      await pumpEventQueue();

      expect(provider.isEmpty, isTrue);
      expect(provider.isLoading, isFalse);
    });

    test('follows a session change to another account', () async {
      // A shared counter tablet, handed over without a sign-out first. Showing
      // the first person's catalogue to the second is the failure this guards.
      final provider = await signedIn('u1', catalogue: [amox]);
      expect(provider.all(), [amox]);

      stores['u2'] = FakeMedicineStore(initial: [cetirizine]);
      await signInAs('u2');

      expect(provider.all(), [cetirizine]);
      expect(requestedFor, ['u1', 'u2']);
    });

    test('keeps the catalogue on a refresh of the same account', () async {
      // Auth re-emits on every token refresh. Re-subscribing here would drop the
      // list back to loading on a timer.
      final provider = await signedIn('u1', catalogue: [amox]);

      await signInAs('u1');

      expect(provider.all(), [amox]);
      expect(provider.isLoading, isFalse);
      expect(requestedFor, [
        'u1',
      ], reason: 'no second read of the same account');
    });

    test('a read that never arrives stays loading rather than empty', () async {
      // "Not loaded yet" and "the pharmacy stocks nothing" look identical if the
      // empty list is shown during the first read.
      await auth.ready;
      stores['u1'] = FakeMedicineStore()..silent = true;
      final provider = MedicineProvider(auth: auth, storeFor: storeFor);
      addTearDown(provider.dispose);

      await signInAs('u1');

      expect(provider.isLoading, isTrue);
      expect(provider.isEmpty, isTrue);
      expect(provider.error, isNull);
    });
  });

  group('recording a count', () {
    test('paints the new count before the write is confirmed', () async {
      final provider = await signedIn('u1', catalogue: [amox]);
      var notified = 0;
      provider.addListener(() => notified++);

      final pending = provider.setStock(amox, 30);

      expect(provider.all().single.stock, 30, reason: 'optimistic');
      expect(notified, greaterThan(0));
      await pending;
      expect(provider.all().single.stock, 30, reason: 'confirmed');
    });

    test('goes back to not counted when the count is cleared', () async {
      // The "Not counted" answer has to survive the optimistic update and not
      // only the write. If the local copy kept 30, the staff member would watch
      // the number they had just removed reappear.
      final provider = await signedIn('u1', catalogue: [cetirizine]);
      await provider.setStock(cetirizine, 30);

      await provider.setStock(cetirizine, null);

      expect(provider.all().single.stock, isNull);
      expect(provider.all().single.stockState, StockState.unknown);
    });

    test('puts the old count back when the write fails', () async {
      final provider = await signedIn('u1', catalogue: [cetirizine]);
      stores['u1']!.writeError = Exception('offline');

      await provider.setStock(cetirizine, 99);

      expect(provider.all().single.stock, 12);
      expect(provider.error, contains('offline'));
    });

    test('clears the error once it has been shown', () async {
      final provider = await signedIn('u1', catalogue: [cetirizine]);
      stores['u1']!.writeError = Exception('offline');
      await provider.setStock(cetirizine, 99);
      expect(provider.error, isNotNull);

      provider.clearError();

      expect(provider.error, isNull);
    });

    test('translates a permission failure into something actionable', () async {
      // A raw FirebaseException is a URL and a code, which tells a pharmacist
      // nothing about what to do next.
      final provider = await signedIn('u1', catalogue: [cetirizine]);
      stores['u1']!.writeError = Exception(
        '[firebase_app/permission-denied] PERMISSION_DENIED',
      );

      await provider.setStock(cetirizine, 5);

      expect(provider.error, contains('security rules'));
      expect(provider.error, isNot(contains('PERMISSION_DENIED')));
    });
  });

  group('recording an expiry', () {
    test('paints the date and keeps it', () async {
      final provider = await signedIn('u1', catalogue: [cetirizine]);
      final expiry = DateTime(2026, 3, 31);

      await provider.setExpiry(cetirizine, expiry);

      expect(provider.all().single.expiryDate, expiry);
    });

    test('clears the date when null is passed', () async {
      final provider = await signedIn('u1', catalogue: [cetirizine]);
      await provider.setExpiry(cetirizine, DateTime(2026, 3, 31));

      await provider.setExpiry(cetirizine, null);

      expect(provider.all().single.expiryDate, isNull);
    });

    test('leaves the count alone', () async {
      // The two are written one key at a time, so neither may drag the other.
      final provider = await signedIn('u1', catalogue: [cetirizine]);
      await provider.setStock(cetirizine, 4);

      await provider.setExpiry(cetirizine, DateTime(2026, 3, 31));

      expect(provider.all().single.stock, 4);
    });
  });

  group('searching', () {
    test('finds a line by its own name', () async {
      final provider = await signedIn('u1', catalogue: [amox, cetirizine]);

      expect(provider.search('ceti'), [cetirizine]);
    });

    test('finds a line by a spelling the counter actually uses', () async {
      final provider = await signedIn('u1', catalogue: [amox, cetirizine]);

      expect(provider.search('ceterizin'), [cetirizine]);
    });

    test('returns everything for an empty query', () async {
      final provider = await signedIn('u1', catalogue: [amox, cetirizine]);

      expect(provider.search('   '), [amox, cetirizine]);
    });

    test('gives an unmodifiable list either way', () async {
      // Screens bind to the result directly, and a list that can be sorted in
      // place behind the provider's back would undo its own ordering -- including
      // for the empty query, which is what a search box shows before it is typed in.
      final provider = await signedIn('u1', catalogue: [amox, cetirizine]);

      expect(() => provider.search('a').add(amox), throwsUnsupportedError);
      expect(() => provider.search('').add(amox), throwsUnsupportedError);
    });
  });

  group('importing a price list', () {
    test('hands the lines to the signed-in account\'s store', () async {
      final provider = await signedIn('u1');

      await provider.importMedicines([amox, cetirizine]);

      expect(stores['u1']!.operations, ['upsertAll 2']);
    });

    test('reports a failed import instead of throwing at the caller', () async {
      final provider = await signedIn('u1');
      stores['u1']!.writeError = Exception('nope');

      await provider.importMedicines([amox]);

      expect(provider.error, contains('nope'));
    });

    test('does nothing when nobody is signed in', () async {
      await auth.ready;
      final provider = MedicineProvider(auth: auth, storeFor: storeFor);
      addTearDown(provider.dispose);

      await provider.importMedicines([amox]);

      expect(stores, isEmpty);
    });
  });
}
