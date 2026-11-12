import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/utils/search_text.dart';
import 'package:pharmaguide/features/admin/data/models/store_settings_model.dart';
import 'package:pharmaguide/features/auth/data/models/user_model.dart';
import 'package:pharmaguide/features/auth/domain/user_role.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/orders/data/models/order_history_model.dart';
import 'package:pharmaguide/features/orders/data/models/order_line_model.dart';
import 'package:pharmaguide/features/reports/data/models/sale_model.dart';
import 'package:pharmaguide/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:pharmaguide/features/reports/data/repositories/sales_repository.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/presentation/providers/medicine_provider.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_medicine_store.dart';
import 'helpers/fake_order_history_repository.dart';

/// The velocity-backed low-stock calculation in
/// [ReportsRepositoryImpl.getLowStockAlerts].
///
/// The join and the target arithmetic are covered unit-by-unit in
/// `reorder_velocity_test.dart`; what only an integration test can say is that
/// the repository feeds the right sources in, marks the uncounted lines, and
/// orders the list the way a reorder would be placed.
void main() {
  late FakeAuthRepository authRepository;
  late AuthProvider auth;
  MedicineProvider? medicines;
  FakeOrderHistoryRepository? history;

  SaleModel sale(
    String rawName, {
    required int day,
    num quantity = 1,
  }) {
    return SaleModel(
      date: DateTime(2026, 1, day),
      kind: SaleKind.counter,
      rawName: rawName,
      key: normaliseForSearch(rawName),
      quantity: quantity,
      priceCentavos: 0,
      totalCentavos: 0,
      sourceSheet: 'test',
    );
  }

  OrderHistory approvedOrder(
    String id,
    String medicineName,
    int quantity,
  ) {
    return OrderHistory(
      id: id,
      time: DateTime(2026, 2, 1, 10),
      status: OrderStatus.approved,
      items: [
        OrderLineModel(
          medicine: MedicineModel(name: medicineName, priceCentavos: 0, stock: null),
          quantity: quantity,
        ),
      ],
      totalCentavos: 0,
    );
  }

  setUp(() async {
    authRepository = FakeAuthRepository(
      currentUser: const UserModel(
        id: 'admin-1',
        name: 'Administrator',
        email: 'a@x.com',
        role: UserRole.admin,
      ),
    );
    auth = AuthProvider(authRepository);
    await auth.ready;
  });

  tearDown(() {
    // Nulled after disposing: a test that signs no catalogue would otherwise
    // dispose the *previous* test's provider a second time, and a disposed
    // ChangeNotifier asserts on that.
    medicines?.dispose();
    medicines = null;
    history?.dispose();
    history = null;
    auth.dispose();
    authRepository.dispose();
    MedicineModel.lowStockThreshold = MedicineModel.defaultLowStockThreshold;
  });

  /// Signs a catalogue in: a provider over [catalogue] plus a fresh history
  /// repository. Per test rather than in `setUp` because the catalogue is the
  /// test's own fixture, and the provider has to be built after the auth
  /// account it reads has resolved. Disposal stays in `tearDown` -- the
  /// provider there is the last one this test created.
  Future<void> signCatalogue(List<MedicineModel> catalogue) async {
    medicines = MedicineProvider(
      auth: auth,
      storeFor: (_) => FakeMedicineStore(initial: catalogue),
    );
    // The first store snapshot lands as a stream event.
    await pumpEventQueue();
    history = FakeOrderHistoryRepository();
  }

  /// The repository under test, over the catalogue the test signed in.
  ReportsRepositoryImpl buildRepository({
    List<SaleModel> sales = const [],
    List<OrderHistory> orders = const [],
  }) {
    history!.dispose();
    history = FakeOrderHistoryRepository(orders);
    return ReportsRepositoryImpl(
      medicineProvider: medicines!,
      historyFactory: () => history!,
      salesLoader: () async => SalesRepository(sales),
    );
  }

  test('the target is coverage days of demand, from the bundled seed', () async {
    // 2 units on each of 10 trading days: 20 units, 2 a day. Fourteen days
    // of that is 28.
    await signCatalogue([
      const MedicineModel(
        name: 'Paracetamol',
        priceCentavos: 0,
        stock: 3,
      ),
    ]);

    final alerts = await buildRepository(
      sales: [
        for (var day = 1; day <= 10; day++)
          sale('Paracetamol', day: day, quantity: 2),
      ],
    ).getLowStockAlerts(
      coverageDays: 14,
    );

    final alert = alerts.single;
    expect(alert.name, 'Paracetamol');
    expect(alert.unitsPerDay, 2.0);
    expect(alert.coverageDays, 14);
    expect(alert.reorderLevel, 28);
    expect(alert.deficit, 25);
    expect(alert.isCritical, isTrue);
  });

  test('the coverage window comes from the caller', () async {
    await signCatalogue([
      const MedicineModel(
        name: 'Paracetamol',
        priceCentavos: 0,
        stock: 3,
      ),
    ]);

    final alerts = await buildRepository(
      sales: [
        for (var day = 1; day <= 10; day++)
          sale('Paracetamol', day: day, quantity: 2),
      ],
    ).getLowStockAlerts(coverageDays: 7);

    expect(alerts.single.coverageDays, 7);
    expect(alerts.single.reorderLevel, 14);
  });

  test('live order history wins over the seed for the same item', () async {
    await signCatalogue([
      const MedicineModel(
        name: 'Paracetamol',
        priceCentavos: 0,
        stock: 3,
      ),
    ]);

    // Live: 7 units on one day = 7/day. The seed (2/day over ten days)
    // loses: live wins, so the target is ceil(7 x 14) = 98, not anything
    // blended with the seed.
    final alerts = await buildRepository(
      sales: [
        for (var day = 1; day <= 10; day++)
          sale('Paracetamol', day: day, quantity: 2),
      ],
      orders: [approvedOrder('o1', 'Paracetamol', 7)],
    ).getLowStockAlerts(coverageDays: 14);

    expect(alerts.single.unitsPerDay, 7.0);
    expect(alerts.single.reorderLevel, 98);
  });

  test('an item that never sold targets the threshold floor', () async {
    await signCatalogue([
      const MedicineModel(
        name: 'Ibuprofen',
        priceCentavos: 0,
        stock: 2,
      ),
    ]);

    // No sales anywhere: velocity is 0, and without the floor the target
    // would be 0 and the deficit 0 -- an alert with nothing to act on.
    final alerts = await buildRepository().getLowStockAlerts(
      coverageDays: 14,
    );

    final alert = alerts.single;
    expect(alert.unitsPerDay, 0.0);
    expect(alert.reorderLevel, MedicineModel.lowStockThreshold);
    expect(alert.deficit, 3);
  });

  test('the threshold the app-wide setting holds is the floor', () async {
    // The settings provider keeps this static in step with Store settings;
    // the repository reads it so a raised threshold raises the floor with it.
    MedicineModel.lowStockThreshold = 9;
    await signCatalogue([
      const MedicineModel(
        name: 'Ibuprofen',
        priceCentavos: 0,
        stock: 2,
      ),
    ]);

    final alerts = await buildRepository().getLowStockAlerts(
      coverageDays: 14,
    );

    expect(alerts.single.reorderLevel, 9);
  });

  test('an uncounted line is flagged, not counted as empty', () async {
    await signCatalogue([
      const MedicineModel(
        name: 'Uncounted Syrup',
        priceCentavos: 0,
        stock: null,
      ),
    ]);

    final alerts = await buildRepository().getLowStockAlerts(
      coverageDays: 14,
    );

    // currentStock reads as 0 for the arithmetic, but the flag is what tells
    // a caller summing deficits that this number was never measured.
    final alert = alerts.single;
    expect(alert.isStockUncounted, isTrue);
    expect(alert.currentStock, 0);
  });

  test('the list orders out-of-stock first, then biggest shortfall', () async {
    await signCatalogue([
      const MedicineModel(name: 'Slow Mover', priceCentavos: 0, stock: 4),
      const MedicineModel(name: 'Fast Mover', priceCentavos: 0, stock: 0),
      const MedicineModel(name: 'Big Gap', priceCentavos: 0, stock: 1),
    ]);

    final alerts = await buildRepository(
      sales: [
        sale('Big Gap', day: 1, quantity: 30),
        sale('Big Gap', day: 2, quantity: 30),
      ],
    ).getLowStockAlerts(coverageDays: 14);

    // Big Gap sells 30/day: target 420, deficit 419 -- the biggest shortfall
    // among the counted lines, so it leads after the empty shelf. Slow Mover
    // has no velocity, targets the threshold, and trails with a deficit of 1.
    expect(
      alerts.map((a) => a.name),
      ['Fast Mover', 'Big Gap', 'Slow Mover'],
    );
    expect(alerts[1].deficit, greaterThan(alerts[2].deficit));
  });

  test('a missing seed does not break the list', () async {
    await signCatalogue([
      const MedicineModel(
        name: 'Paracetamol',
        priceCentavos: 0,
        stock: 3,
      ),
    ]);

    final repository = ReportsRepositoryImpl(
      medicineProvider: medicines!,
      historyFactory: () => history!,
      salesLoader: () async => null,
    );

    final alerts = await repository.getLowStockAlerts(
      coverageDays: StoreSettingsModel.defaultReorderCoverageDays,
    );

    // Threshold-floor targets, and the list still answers.
    expect(alerts.single.reorderLevel, MedicineModel.lowStockThreshold);
  });

  test('the default coverage sits in the middle of the choices', () {
    expect(StoreSettingsModel.reorderCoverageChoices, [7, 14, 30]);
    expect(
      StoreSettingsModel.defaultReorderCoverageDays,
      14,
      reason: 'not an extreme of the choice list: long enough to ride out a '
          "supplier's lead time, short enough to stay honest to demand",
    );
  });
}
