import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/auth/data/models/user_model.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/search/data/models/age_guidance.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/presentation/providers/medicine_provider.dart';
import 'package:pharmaguide/features/search/presentation/screens/medicine_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_medicine_store.dart';

/// The medicine details sheet is where most of the imported workbook columns
/// become visible. If a field is plumbed into the model but never drawn, this is
/// the only test that would notice.
void main() {
  const medicine = MedicineModel(
    name: 'Efficascent Oil Regular 100mL',
    productId: '97',
    priceCentavos: 5800,
    stock: 20,
    packageType: 'Bottle (100mL)',
    usageIndication: 'Liniment for muscle pain, cramps, and headache',
    category: 'First Aid & Topicals',
    ageGroup: AgeGroup.both,
    ageGuidance: AgeGuidance(
      kids: AgeSuitability.caution,
      teens: AgeSuitability.yes,
      adults: AgeSuitability.yes,
      seniors: AgeSuitability.yes,
    ),
    dosageInfo:
        'Apply up to 3 times a day as needed. Massage a small amount on the '
        'affected area. Wash hands after use.',
    cautions: 'External use only. Not for children under 2.',
  );

  testWidgets('shows the imported age, directions, category and cautions',
      (tester) async {
    final authRepository = FakeAuthRepository();
    final auth = AuthProvider(authRepository);
    await auth.ready;

    final store = FakeMedicineStore(initial: const [medicine]);
    addTearDown(store.dispose);
    final catalogue = MedicineProvider(auth: auth, storeFor: (_) => store);
    addTearDown(catalogue.dispose);
    addTearDown(auth.dispose);
    addTearDown(authRepository.dispose);

    authRepository.emit(
      const UserModel(id: '1', name: 'Counter', email: 'counter@example.com'),
    );
    // A pump loads the catalogue: pumpEventQueue is unusable inside a widget
    // test, because its event-loop turns are fake timers no pump ever advances.
    await tester.pump();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: catalogue),
        ],
        child: const MaterialApp(home: MedicineScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(catalogue.isLoading, isFalse, reason: 'catalogue did not load');

    await tester.tap(find.text('Bottle (100mL)'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );

    expect(find.text('Category'), findsOneWidget);
    expect(find.text('First Aid & Topicals'), findsOneWidget);
    expect(find.text('Suitable for'), findsOneWidget);
    expect(
      find.text('Kids (caution), Teens, Adults, Seniors'),
      findsOneWidget,
    );
    expect(find.text('Directions'), findsOneWidget);
    expect(
      find.textContaining('Apply up to 3 times a day'),
      findsOneWidget,
    );
    expect(
      find.textContaining('External use only. Not for children under 2.'),
      findsOneWidget,
    );
    expect(find.textContaining('not medical advice'), findsOneWidget);
  });
}
