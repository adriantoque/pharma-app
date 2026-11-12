import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/admin/data/models/store_settings_model.dart';
import 'package:pharmaguide/features/admin/data/repositories/audit_repository.dart';
import 'package:pharmaguide/features/admin/data/repositories/store_settings_repository.dart';
import 'package:pharmaguide/features/admin/domain/audit_event.dart';
import 'package:pharmaguide/features/admin/presentation/providers/store_settings_provider.dart';
import 'package:pharmaguide/features/admin/presentation/screens/store_settings_screen.dart';
import 'package:pharmaguide/features/auth/data/models/user_model.dart';
import 'package:pharmaguide/features/auth/domain/user_role.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_audit_repository.dart';
import 'helpers/fake_auth_repository.dart';

/// The settings screen against an in-memory repository and a signed-in admin.
///
/// The Firestore-backed repository is covered in
/// `store_settings_repository_test.dart`; what only a widget test can say is
/// that the rows read the provider, the sheets edit it, and the Save button
/// writes and logs.
///
/// Everything is constructed inside the test body, not in `setUp`: a
/// stream-subscribing provider built in `setUp` lives outside the fake-async
/// zone the widget tests run in, and the first `pumpWidget` then never
/// resolves. `admin_home_test.dart` reaches the same conclusion for its
/// providers.
void main() {
  late FakeAuthRepository authRepository;
  late AuthProvider auth;
  late InMemoryStoreSettingsRepository settingsRepository;
  late FakeAuditRepository auditRepository;
  late StoreSettingsProvider provider;

  /// Fresh harness per test, constructed inside the test's zone.
  Future<void> buildHarness() async {
    authRepository = FakeAuthRepository(
      currentUser: const UserModel(
        id: 'admin-1',
        name: 'Administrator',
        email: 'admin@pharmaguide.local',
        role: UserRole.admin,
      ),
    );
    auth = AuthProvider(authRepository);
    settingsRepository = InMemoryStoreSettingsRepository();
    auditRepository = FakeAuditRepository();
    provider = StoreSettingsProvider(
      repository: settingsRepository,
      audit: auditRepository,
      auth: auth,
    );
    addTearDown(() {
      provider.dispose();
      auth.dispose();
      authRepository.dispose();
      auditRepository.dispose();
    });
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    // The signed-in account resolves asynchronously through the auth
    // provider's session verification; every save logs who performed it, so
    // the actor has to exist before the first tap.
    await auth.ready;

    // Tall enough that the whole list is laid out: the footer and the rules
    // section sit below the default 800x600 fold, and a lazy ListView would
    // make their finders miss for the wrong reason.
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<StoreSettingsProvider>.value(value: provider),
          Provider<AuditRepository>.value(value: auditRepository),
        ],
        child: const MaterialApp(home: StoreSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Types [text] into the open sheet and saves it, leaving the sheet closed.
  Future<void> saveSheet(WidgetTester tester, String text) async {
    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    await tester.enterText(field, text);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders every section with the defaults an install starts on', (
    tester,
  ) async {
    await buildHarness();
    await pumpScreen(tester);

    expect(find.text('Store profile'), findsOneWidget);
    expect(find.text('Business hours'), findsOneWidget);
    expect(find.text('Stock & expiry rules'), findsOneWidget);

    // Defaults, so a store that never saved anything still reads sensibly.
    expect(find.text('Not set yet'), findsNWidgets(3));
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('5:00 PM'), findsOneWidget);
    expect(find.text('5 items'), findsOneWidget);
    expect(find.text('90 days'), findsOneWidget);

    // And the footer tells the truth about it.
    expect(find.textContaining('Not saved yet'), findsOneWidget);

    // No Save button: there is nothing to save, and a button that writes
    // nothing would read as a failure.
    expect(find.text('Save changes'), findsNothing);
  });

  testWidgets('editing a row opens a one-field sheet and marks the screen dirty', (
    tester,
  ) async {
    await buildHarness();
    await pumpScreen(tester);

    await tester.tap(find.text('Store name'));
    await tester.pumpAndSettle();

    await saveSheet(tester, 'Rosedale Pharmacy');

    // The value shows on the row, and the Save button appeared because the
    // working copy now differs from the (still empty) saved document.
    expect(find.text('Rosedale Pharmacy'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);

    // Nothing has been written yet: the repository is untouched until Save.
    expect(settingsRepository.value, isNull);
  });

  testWidgets('Save writes the repository and logs the change', (tester) async {
    await buildHarness();
    await pumpScreen(tester);

    await tester.tap(find.text('Store name'));
    await tester.pumpAndSettle();
    await saveSheet(tester, 'Rosedale Pharmacy');

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(settingsRepository.value?.name, 'Rosedale Pharmacy');
    expect(find.text('Settings saved.'), findsOneWidget);

    // The save button goes away again: the working copy now matches what is
    // saved, so there is nothing left to save.
    expect(find.text('Save changes'), findsNothing);

    // The audit log recorded it under the settings category, with the actor
    // the signed-in account provided.
    expect(auditRepository.recorded, hasLength(1));
    final event = auditRepository.recorded.single;
    expect(event.action, AuditAction.settingsUpdated);
    expect(event.actorUid, 'admin-1');
    expect(event.summary, contains('name'));
  });

  testWidgets('an invalid edit is refused by the sheet, not by the save', (
    tester,
  ) async {
    await buildHarness();
    await pumpScreen(tester);

    await tester.tap(find.text('Store name'));
    await tester.pumpAndSettle();

    // Saving an empty name is refused inside the sheet, which stays open.
    await saveSheet(tester, '');
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Give the store a name.'), findsOneWidget);

    // Nothing dirty, nothing logged.
    expect(find.text('Save changes'), findsNothing);
    expect(auditRepository.recorded, isEmpty);
  });

  testWidgets('the threshold sheet refuses a number outside its range', (
    tester,
  ) async {
    await buildHarness();
    await pumpScreen(tester);

    await tester.tap(find.text('Low-stock threshold'));
    await tester.pumpAndSettle();

    await saveSheet(tester, '0');
    expect(find.text('Enter a whole number from 1 to 99.'), findsOneWidget);
    expect(find.text('Save changes'), findsNothing);

    // And a valid value goes through.
    await saveSheet(tester, '12');
    expect(find.text('12 items'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('the expiry window is a choice of three', (tester) async {
    await buildHarness();
    await pumpScreen(tester);

    // A name first: Save refuses a settings set with no store name, and this
    // test is about the window, not about that guard.
    provider.updateName('Rosedale Pharmacy');

    await tester.tap(find.text('Expiry warning'));
    await tester.pumpAndSettle();

    // Tapping a chip closes the sheet immediately: the choice was made the
    // moment it was read.
    await tester.tap(find.text('60 days'));
    await tester.pumpAndSettle();

    expect(find.text('60 days'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(settingsRepository.value?.expiryWarningDays, 60);
  });

  testWidgets('discarding the working copy restores the saved values', (
    tester,
  ) async {
    await buildHarness();
    await settingsRepository.save(const StoreSettingsModel(name: 'Saved name'));
    await pumpScreen(tester);

    await tester.tap(find.text('Store name'));
    await tester.pumpAndSettle();
    await saveSheet(tester, 'Unsaved name');
    expect(find.text('Unsaved name'), findsOneWidget);

    provider.discard();
    await tester.pumpAndSettle();

    expect(find.text('Saved name'), findsOneWidget);
    expect(find.text('Save changes'), findsNothing);
  });

  testWidgets('hours validate against each other before anything is saved', (
    tester,
  ) async {
    // A baseline where "opens at" already equals "closes at": re-confirming
    // the opening time is then an opening at-or-after the close, which the
    // editor refuses inline. The alternative -- driving the time picker's
    // hour entry -- would test Flutter's dialog, not this screen.
    await buildHarness();
    await settingsRepository.save(
      const StoreSettingsModel(
        name: 'Baseline',
        openMinutes: 17 * 60,
        closeMinutes: 17 * 60,
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('Opens at'));
    await tester.pumpAndSettle();

    // The picker opens at the current value; confirming it unchanged is the
    // cheapest way to hand back 5:00 PM.
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text('Opening time must be before closing time.'),
      findsOneWidget,
    );
    expect(find.text('Save changes'), findsNothing);
  });
}
