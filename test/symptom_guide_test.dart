import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/presentation/providers/medicine_provider.dart';
import 'package:pharmaguide/features/symptom_guide/data/models/symptom_entry.dart';
import 'package:pharmaguide/features/symptom_guide/presentation/providers/symptom_search_provider.dart';
import 'package:pharmaguide/features/symptom_guide/presentation/screens/symptom_detail_screen.dart';
import 'package:pharmaguide/features/symptom_guide/presentation/screens/symptom_search_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_medicine_store.dart';
import 'helpers/fake_order_history_repository.dart';

void main() {
  group('SymptomEntry.matches', () {
    const entry = SymptomEntry(
      id: 'fever',
      name: 'Fever',
      summary: 'A raised temperature.',
      aliases: ['lagnat', 'temperature'],
    );

    test('an empty query matches everything', () {
      expect(entry.matches(''), isTrue);
      expect(entry.matches('   '), isTrue);
    });

    test('matches its name case-insensitively', () {
      expect(entry.matches('fEvEr'), isTrue);
    });

    test('matches an alias', () {
      expect(entry.matches('lagnat'), isTrue);
    });

    test('a query that names nothing does not match', () {
      expect(entry.matches('zzzz'), isFalse);
    });

    test('a punctuation-only query matches everything', () {
      expect(entry.matches('---'), isTrue);
    });
  });

  group('MedicineModel.matchesIndication', () {
    const fever = MedicineModel(
      name: 'Biogesic 500mg Tablet (Paracetamol)',
      priceCentavos: 600,
      stock: 10,
      usageIndication: 'For fever, headache, and body aches',
    );

    test('matches a word in the indication', () {
      expect(fever.matchesIndication('fever'), isTrue);
      expect(fever.matchesIndication('headache'), isTrue);
    });

    test('folds case and stray punctuation like search does', () {
      expect(fever.matchesIndication('HEAD ACHE'), isTrue);
    });

    test('ignores a term too short to name a symptom', () {
      expect(fever.matchesIndication('fe'), isFalse);
    });

    test('a line with no recorded indication never matches', () {
      const noIndication = MedicineModel(
        name: 'Some Item',
        priceCentavos: 100,
        stock: 1,
      );
      expect(noIndication.matchesIndication('fever'), isFalse);
    });
  });

  group('SymptomEntry.recommendationsIn', () {
    const entry = SymptomEntry(
      id: 'fever',
      name: 'Fever',
      summary: 'A raised temperature.',
      aliases: ['lagnat'],
      medicineNames: [
        'Biogesic 500mg Tablet (Paracetamol)',
        'Paracetamol 500mg (Generic Tablet)',
      ],
    );

    const biogesicOut = MedicineModel(
      name: 'Biogesic 500mg Tablet (Paracetamol)',
      priceCentavos: 500,
      stock: 0,
    );
    const biogesicIn = MedicineModel(
      name: 'Biogesic 500mg Tablet (Paracetamol)',
      priceCentavos: 700,
      stock: 12,
    );
    const paracetamol = MedicineModel(
      name: 'Paracetamol 500mg (Generic Tablet)',
      priceCentavos: 200,
      stock: 50,
    );
    const feverIndicated = MedicineModel(
      name: 'Alaxan FR Capsule',
      priceCentavos: 800,
      stock: 3,
      usageIndication: 'For pain relief, fever, and anti-inflammation',
    );
    const unrelated = MedicineModel(
      name: 'Vicks Vaporub Ointment 25g',
      priceCentavos: 300,
      stock: 5,
      usageIndication: 'Vaporizing ointment for cough and nasal congestion',
    );
    const absent = MedicineModel(
      name: 'Some Other Product',
      priceCentavos: 100,
      stock: 3,
    );

    test('leads with the curated picks, in the order they were written', () {
      final recommendations = entry.recommendationsIn([
        paracetamol,
        biogesicIn,
        unrelated,
      ]);

      expect(recommendations.map((medicine) => medicine.name), [
        'Biogesic 500mg Tablet (Paracetamol)',
        'Paracetamol 500mg (Generic Tablet)',
      ]);
    });

    test('keeps the in-stock variant of a repeated name', () {
      final recommendations = entry.recommendationsIn([biogesicOut, biogesicIn]);

      expect(recommendations.single.stock, 12);
    });

    test('falls back to the cheapest when none of the variants is in stock', () {
      const cheaperOut = MedicineModel(
        name: 'Biogesic 500mg Tablet (Paracetamol)',
        priceCentavos: 400,
        stock: 0,
      );

      final recommendations = entry.recommendationsIn([biogesicOut, cheaperOut]);

      expect(recommendations.single.priceCentavos, 400);
    });

    test('adds medicines the catalogue indicates for the symptom', () {
      final recommendations = entry.recommendationsIn([feverIndicated, absent]);

      expect(recommendations.map((medicine) => medicine.name), [
        'Alaxan FR Capsule',
      ]);
    });

    test('does not repeat a curated pick as an indication match', () {
      final indicated = paracetamol.copyWith(
        usageIndication: 'For fever and mild pain',
      );

      expect(entry.recommendationsIn([indicated]), hasLength(1));
    });

    test('offers nothing when the catalogue has nothing for the symptom', () {
      expect(entry.recommendationsIn([absent]), isEmpty);
    });
  });

  group('the symptom detail screen', () {
    testWidgets('lists medicines the catalogue indicates for the symptom', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        symptomId: 'fever',
        medicines: const [
          MedicineModel(
            name: 'Biogesic 500mg Tablet (Paracetamol)',
            priceCentavos: 600,
            stock: 10,
            usageIndication: 'For fever, headache, and body aches',
          ),
          MedicineModel(
            name: 'Vicks Vaporub Ointment 25g',
            priceCentavos: 300,
            stock: 5,
            usageIndication:
                'Vaporizing ointment for cough and nasal congestion',
          ),
        ],
      );

      expect(find.text('Biogesic 500mg Tablet (Paracetamol)'), findsOneWidget);
      expect(find.text('₱6.00'), findsOneWidget);
      // Guidance is looked up by name, not fallback text.
      expect(find.textContaining('Swallow with water'), findsOneWidget);
      // The cough medicine has nothing to do with fever.
      expect(find.text('Vicks Vaporub Ointment 25g'), findsNothing);
    });

    testWidgets('falls back to "ask the pharmacist" when no guidance exists', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        symptomId: 'fever',
        medicines: const [
          MedicineModel(
            name: 'Alaxan FR Capsule',
            priceCentavos: 800,
            stock: 3,
            usageIndication: 'For pain relief, fever, and anti-inflammation',
          ),
        ],
      );

      expect(
        find.textContaining('Directions for this medicine are not recorded'),
        findsOneWidget,
      );
    });

    testWidgets('an out-of-stock medicine cannot be added', (tester) async {
      await pumpDetail(
        tester,
        symptomId: 'cough',
        medicines: const [
          MedicineModel(
            name: 'Solmux 500mg Capsule (Carbocisteine)',
            priceCentavos: 900,
            stock: 0,
            usageIndication: 'For cough with phlegm (mucolytic)',
          ),
        ],
      );

      final button = tester.widget<OutlinedButton>(
        find.byKey(
          const Key('addSolmux 500mg Capsule (Carbocisteine)'),
        ),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Out of stock'), findsOneWidget);
    });

    testWidgets('adds a suggested medicine through the quantity sheet', (
      tester,
    ) async {
      final order = await pumpDetail(
        tester,
        symptomId: 'fever',
        medicines: const [
          MedicineModel(
            name: 'Biogesic 500mg Tablet (Paracetamol)',
            priceCentavos: 600,
            stock: 10,
            usageIndication: 'For fever, headache, and body aches',
          ),
        ],
      );

      await tester.ensureVisible(
        find.byKey(
          const Key('addBiogesic 500mg Tablet (Paracetamol)'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const Key('addBiogesic 500mg Tablet (Paracetamol)'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add to order'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Add to order'));
      await tester.pumpAndSettle();

      expect(order.itemCount, 1);
      expect(find.textContaining('Added 1'), findsOneWidget);
    });

    testWidgets('an unknown symptom id says so rather than crashing', (
      tester,
    ) async {
      await pumpDetail(tester, symptomId: 'no-such-symptom', medicines: const []);

      expect(find.text('Symptom not found'), findsOneWidget);
    });
  });

  group('the symptom search screen', () {
    testWidgets('lists every symptom when nothing is typed', (tester) async {
      await pumpSearch(tester);

      expect(find.text('Fever'), findsOneWidget);
      expect(find.text('Headache'), findsOneWidget);
      expect(find.text('Cough'), findsOneWidget);
      expect(find.text('Allergy'), findsOneWidget);
    });

    testWidgets('filters to the symptom whose alias was typed', (tester) async {
      await pumpSearch(tester);

      await tester.enterText(find.byType(TextField), 'lagnat');
      await tester.pumpAndSettle();

      expect(find.text('Fever'), findsOneWidget);
      expect(find.text('Cough'), findsNothing);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await pumpSearch(tester);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.textContaining('No symptom matches'), findsOneWidget);
    });
  });
}

/// Builds the detail screen over a fake, signed-in catalogue and returns the
/// order it will add into.
Future<OrderProvider> pumpDetail(
  WidgetTester tester, {
  required String symptomId,
  required List<MedicineModel> medicines,
}) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final authRepository = FakeAuthRepository();
  final auth = AuthProvider(authRepository);
  await auth.ready;
  await auth.login(email: 'a@b.com', password: 'secret');

  final store = FakeMedicineStore(initial: medicines);
  final catalogue = MedicineProvider(auth: auth, storeFor: (_) => store);
  final history = FakeOrderHistoryRepository();
  final order = OrderProvider(
    auth: auth,
    catalogue: catalogue,
    historyFor: (_) => history,
  );

  addTearDown(() {
    order.dispose();
    history.dispose();
    store.dispose();
    catalogue.dispose();
    auth.dispose();
    authRepository.dispose();
  });

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<OrderProvider>.value(value: order),
        ChangeNotifierProvider<MedicineProvider>.value(value: catalogue),
        ChangeNotifierProvider(create: (_) => SymptomSearchProvider()),
      ],
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: SymptomDetailScreen(symptomId: symptomId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return order;
}

/// Builds the search screen over the real, in-binary symptom catalogue.
Future<void> pumpSearch(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => SymptomSearchProvider(),
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const SymptomSearchScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
