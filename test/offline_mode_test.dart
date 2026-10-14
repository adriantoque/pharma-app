import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/auth/data/models/user_model.dart';
import 'package:pharmaguide/features/auth/data/repositories/offline_session.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/orders/data/models/order_line_model.dart';
import 'package:pharmaguide/features/orders/data/repositories/local_order_draft_store.dart';
import 'package:pharmaguide/features/orders/data/repositories/order_line_codec.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/data/repositories/bundled_medicine_source.dart';
import 'package:pharmaguide/features/search/data/repositories/local_medicine_store.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_repository.dart';
import 'package:pharmaguide/features/search/data/sync/sync_status.dart';
import 'package:pharmaguide/features/search/presentation/providers/medicine_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late InMemoryOfflineSession session;
  AuthProvider? provider;

  setUpAll(() async {
    repository = FakeAuthRepository();
    session = InMemoryOfflineSession();
  });

  tearDownAll(() {
    provider?.dispose();
    provider = null;
    repository.dispose();
  });

  AuthProvider createProvider() =>
      provider = AuthProvider(repository, offlineSession: session);

  group('offline session', () {
    test('entering offline mode sets the status, the user and the flag', () async {
      final auth = createProvider();
      await auth.ready;
      expect(auth.status, AuthStatus.unauthenticated);

      await auth.enterOfflineMode();

      expect(auth.status, AuthStatus.offline);
      expect(auth.isOffline, isTrue);
      expect(auth.user?.id, AuthProvider.offlineUserId);
      await pumpEventQueue();
      expect(await session.read(), isTrue);
    });

    test('exiting offline mode returns to unauthenticated', () async {
      final auth = createProvider();
      await auth.ready;
      await auth.enterOfflineMode();

      await auth.exitOfflineMode();

      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.isOffline, isFalse);
      expect(auth.user, isNull);
      await pumpEventQueue();
      expect(await session.read(), isFalse);
    });

    // The persisted flag is what makes a cold start go straight to the price
    // list, so a provider built over a set flag has to resolve into offline mode
    // rather than dropping the user on the login screen.
    test('a persisted flag resolves into offline mode on a cold start', () async {
      session = InMemoryOfflineSession(true);

      final auth = createProvider();
      await auth.ready;

      expect(auth.status, AuthStatus.offline);
      expect(auth.user?.id, AuthProvider.offlineUserId);
    });

    // A real Firebase session is the stronger fact. Leaving a stale flag to win
    // would strand a signed-in pharmacist in a guest session on their own device.
    test('a real session outranks a stale offline flag', () async {
      session = InMemoryOfflineSession(true);
      repository.currentUser = UserModel(id: '1', name: 'Ada', email: 'a@b.com');

      final auth = createProvider();
      await auth.ready;

      expect(auth.status, AuthStatus.authenticated);
      expect(auth.user?.email, 'a@b.com');
      await pumpEventQueue();
      expect(await session.read(), isFalse);
    });

    // Regression: _applyAuthState used to infer the status purely from
    // `user == null`, so the first null event off the auth stream would stomp
    // offline mode back to unauthenticated a frame after entering it.
    test('a null auth event does not drop out of offline mode', () async {
      final auth = createProvider();
      await auth.ready;
      await auth.enterOfflineMode();

      repository.emit(null);
      await pumpEventQueue();

      expect(auth.status, AuthStatus.offline);
      expect(auth.isOffline, isTrue);
    });

    test('a real sign-in replaces offline mode', () async {
      final auth = createProvider();
      await auth.ready;
      await auth.enterOfflineMode();

      await auth.login(email: 'a@b.com', password: 'secret');

      expect(auth.status, AuthStatus.authenticated);
      expect(auth.isOffline, isFalse);
      await pumpEventQueue();
      expect(await session.read(), isFalse);
    });

    test('signing out of a real session clears the flag too', () async {
      final auth = createProvider();
      await auth.ready;
      await auth.login(email: 'a@b.com', password: 'secret');

      expect(await auth.logout(), isTrue);

      expect(auth.status, AuthStatus.unauthenticated);
      await pumpEventQueue();
      expect(await session.read(), isFalse);
    });
  });

  group('LocalMedicineStore', () {
    const amox = MedicineModel(
      name: 'Amox',
      priceCentavos: 400,
      stock: null,
    );
    const cetirizine = MedicineModel(
      name: 'Cetirizine',
      priceCentavos: 1200,
      stock: null,
    );

    setUp(() => SharedPreferences.setMockInitialValues({}));

    LocalMedicineStore buildStore() => LocalMedicineStore(
          bundled: ListMedicineSource(const [amox, cetirizine]),
        );

    LocalMedicineStore buildRestartedStore() => LocalMedicineStore(
          bundled: ListMedicineSource(const [amox, cetirizine]),
        );

    Future<List<MedicineModel>> firstList(
      LocalMedicineStore store,
    ) async =>
        store.watchAll().first;

    test('serves the bundled price list with nothing on top', () async {
      final medicines = await firstList(buildStore());

      expect(medicines.map((m) => m.name), ['Amox', 'Cetirizine']);
      expect(medicines.every((m) => m.isStockUnknown), isTrue);
    });

    test('reports localOnly so the offline banner stays hidden', () async {
      final store = buildStore();

      expect(await store.watchSyncStatus().first, SyncStatus.localOnly);
    });

    test('a stock count is applied and re-emitted', () async {
      final store = buildStore();
      final emissions = <List<MedicineModel>>[];
      final sub = store.watchAll().listen(emissions.add);
      // Cancelled when the test ends: an open subscription outlives the store
      // it is watching and leaks between tests.
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await store.setStock(amox, 7);
      await pumpEventQueue();

      expect(emissions, isNotEmpty);
      final latest = emissions.last;
      expect(latest.firstWhere((m) => m.name == 'Amox').stock, 7);
      expect(latest.firstWhere((m) => m.name == 'Cetirizine').isStockUnknown, isTrue);
    });

    test('an expiry date survives a restart', () async {
      final store = buildStore();
      await store.setExpiry(cetirizine, DateTime(2027, 3, 9));

      final medicines = await firstList(buildRestartedStore());

      final line = medicines.firstWhere((m) => m.name == 'Cetirizine');
      expect(line.expiryDate, DateTime(2027, 3, 9));
      expect(line.isStockUnknown, isTrue);
    });

    test('a stock count survives a restart', () async {
      final store = buildStore();
      await store.setStock(amox, 3);

      final medicines = await firstList(buildRestartedStore());

      expect(medicines.firstWhere((m) => m.name == 'Amox').stock, 3);
    });

    test('migrates a legacy overlay to a unique product ID', () async {
      const legacy = MedicineModel(
        name: 'Paracetamol',
        priceCentavos: 200,
        stock: null,
      );
      const imported = MedicineModel(
        productId: '101',
        name: 'Paracetamol',
        packageType: 'Piece (Dosage)',
        priceCentavos: 200,
        stock: 20,
      );
      SharedPreferences.setMockInitialValues({
        'offlineMedicinesOverlay': jsonEncode({
          legacy.documentId: {
            'stock': 3,
            'expiryDate': '2027-01-15',
          },
        }),
      });

      final store = LocalMedicineStore(
        bundled: ListMedicineSource(const [imported]),
      );

      final medicines = await firstList(store);
      final prefs = await SharedPreferences.getInstance();
      final savedOverlay =
          jsonDecode(prefs.getString('offlineMedicinesOverlay')!) as Map;

      expect(medicines.single.stock, 3);
      expect(medicines.single.expiryDate, DateTime(2027, 1, 15));
      expect(savedOverlay.containsKey(imported.documentId), isTrue);
      expect(savedOverlay.containsKey(legacy.documentId), isFalse);
    });

    test('clearing a count back to uncounted is stored as a real value', () async {
      final store = buildStore();
      await store.setStock(amox, 5);
      await store.setStock(amox, null);

      final medicines = await firstList(buildRestartedStore());

      expect(medicines.firstWhere((m) => m.name == 'Amox').stock, isNull);
      expect(medicines.firstWhere((m) => m.name == 'Amox').isStockUnknown, isTrue);
    });

    test('corrupt overlay storage is ignored rather than fatal', () async {
      SharedPreferences.setMockInitialValues({
        'offlineMedicinesOverlay': 'not json at all',
      });
      final store = buildStore();

      final medicines = await firstList(store);

      expect(medicines, hasLength(2));
    });
  });

  group('LocalOrderDraftStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    LocalOrderDraftStore buildStore() => LocalOrderDraftStore();

    test('an account that never had a draft reads as empty', () async {
      final store = buildStore();

      expect(await store.watchDraft().first, isEmpty);
    });

    test('a saved basket comes back after a restart', () async {
      final store = buildStore();
      await store.save([
        OrderLineModel(
          medicine: const MedicineModel(name: 'Amox', priceCentavos: 400, stock: null),
          quantity: 3,
        ),
      ]);

      final restored = await buildStore().watchDraft().first;
      expect(restored, hasLength(1));
      expect(restored.single.medicine.stock, isNull);
      expect(restored.single.quantity, 3);
    });

    test('clearing empties the stored draft', () async {
      final store = buildStore();
      await store.save([
        OrderLineModel(
          medicine: const MedicineModel(name: 'Amox', priceCentavos: 400, stock: null),
          quantity: 2,
        ),
      ]);

      await store.clear();

      expect(await buildStore().watchDraft().first, isEmpty);
    });

    test('corrupt storage reads as an empty basket rather than throwing', () async {
      SharedPreferences.setMockInitialValues({
        'offlineOrderDraft': '{{{',
      });

      expect(await buildStore().watchDraft().first, isEmpty);
    });

    test('a line that cannot be read is skipped, not fatal', () async {
      SharedPreferences.setMockInitialValues({
        'offlineOrderDraft': '{"lines":[{"name":"Amox","priceCentavos":400,"quantity":2},{"name":""},{"nope":true}]}',
      });

      final lines = await buildStore().watchDraft().first;

      expect(lines, hasLength(1));
      expect(lines.single.medicine.name, 'Amox');
    });
  });

  group('OrderLineCodec', () {
    test('a zero quantity is not a line', () {
      final decoded = OrderLineCodec.readLine({
        'name': 'Amox',
        'priceCentavos': 400,
        'quantity': 0,
      });

      expect(decoded, isNull);
    });

    test('a line survives a round trip through the stored shape', () {
      final line = OrderLineModel(
        medicine: const MedicineModel(
          name: 'Amox',
          priceCentavos: 4500,
          stock: 9,
        ),
        quantity: 2,
      );

      final restored = OrderLineCodec.readLine(OrderLineCodec.toMap(line));

      expect(restored, isNotNull);
      expect(restored!.quantity, 2);
      expect(restored.medicine, line.medicine);
      expect(restored.medicine.stock, isNull);
    });
  });

  group('providers in offline mode', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('the medicine provider builds a store for the offline user', () async {
      final auth = createProvider();
      await auth.ready;
      await auth.enterOfflineMode();

      final store = LocalMedicineStore(
        bundled: ListMedicineSource(
          const StaticMedicineRepository().all(),
        ),
      );

      final medicines = MedicineProvider(
        auth: auth,
        storeFor: (uid) => store,
      );

      expect(auth.user!.id, AuthProvider.offlineUserId);
      await pumpEventQueue();

      expect(medicines.isEmpty, isFalse);
      expect(medicines.syncStatus, SyncStatus.localOnly);
    });

    test('the order provider builds a draft store for the offline user', () async {
      final auth = createProvider();
      await auth.ready;
      await auth.enterOfflineMode();

      const catalogue = StaticMedicineRepository();
      final orders = OrderProvider(
        auth: auth,
        catalogue: catalogue,
        draftFor: (uid) => LocalOrderDraftStore(),
      );

      await pumpEventQueue();

      final bioflu = catalogue.all().firstWhere(
        (m) => m.name == 'Bioflu Tablet',
      );
      orders.add(bioflu, 2);
      await pumpEventQueue();

      expect(orders.lines, hasLength(1));
      expect(orders.itemCount, 2);
    });
  });
}