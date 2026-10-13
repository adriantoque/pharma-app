import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/dashboard/presentation/screens/expiring_meds_screen.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/presentation/providers/medicine_provider.dart';
import 'package:provider/provider.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_medicine_store.dart';

void main() {
  setUp(() {
    // Pinned so "Expires in 10 days" does not drift with the wall clock.
    MedicineModel.debugToday = () => DateTime(2026, 1, 1);
  });

  tearDown(() => MedicineModel.debugToday = DateTime.now);

  /// Pumps the screen signed in, and lets the catalogue's first snapshot land.
  ///
  /// The providers are built here rather than in `setUp` so their futures run
  /// inside the widget test's zone. Deliberately not `pumpAndSettle` for the
  /// load: until the snapshot arrives the screen shows a progress indicator,
  /// which never stops animating and so never settles.
  Future<void> pump(
    WidgetTester tester, {
    required List<MedicineModel> catalogue,
  }) async {
    final authRepository = FakeAuthRepository();
    final auth = AuthProvider(authRepository);
    await auth.ready;
    await auth.login(email: 'a@b.com', password: 'secret');

    final store = FakeMedicineStore(initial: catalogue);
    final provider = MedicineProvider(auth: auth, storeFor: (_) => store);

    addTearDown(() {
      provider.dispose();
      auth.dispose();
      authRepository.dispose();
      store.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<MedicineProvider>.value(value: provider),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const ExpiringMedsScreen(),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('exports the dated list as CSV', (tester) async {
    await pump(
      tester,
      catalogue: [
        MedicineModel(
          name: 'Amoxicillin',
          priceCentavos: 400,
          stock: 5,
          expiryDate: DateTime(2026, 1, 11),
        ),
      ],
    );

    await tester.tap(find.byTooltip('Export expiring list'));
    // Not pumpAndSettle: the dialog's selectable text blinks a cursor forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Expiring Meds CSV Export'), findsOneWidget);
    final sheet = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(sheet.data, startsWith('Name,Expiry,Status'));
    expect(sheet.data, contains('Amoxicillin,2026-01-11,Expires in 10 days'));
  });

  testWidgets('offers no export when nothing has a date', (tester) async {
    await pump(
      tester,
      catalogue: [
        MedicineModel(name: 'Amoxicillin', priceCentavos: 400, stock: 5),
      ],
    );

    expect(find.byTooltip('Export expiring list'), findsNothing);
  });
}
