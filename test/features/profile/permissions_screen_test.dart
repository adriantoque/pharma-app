import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/auth/data/repositories/offline_session.dart';
import 'package:pharmaguide/features/auth/domain/user_role.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/profile/presentation/screens/permissions_screen.dart';
import 'package:provider/provider.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late AuthProvider auth;

  setUp(() => repository = FakeAuthRepository());

  tearDown(() {
    auth.dispose();
    repository.dispose();
  });

  /// Pumps the screen for an account remembered as [role]. The session is
  /// restored offline so [AuthProvider] reads the role from the store rather
  /// than needing a signed-in Firebase user.
  Future<void> pumpFor(WidgetTester tester, UserRole role) async {
    auth = AuthProvider(
      repository,
      roleStore: InMemoryRoleStore(role),
      offlineSession: InMemoryOfflineSession(true),
    );
    await auth.ready;

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const PermissionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an admin is allowed everything', (tester) async {
    await pumpFor(tester, UserRole.admin);

    expect(find.text('Admin account'), findsOneWidget);
    expect(find.text('Allowed'), findsNWidgets(6));
    expect(find.text('Not allowed'), findsNothing);
  });

  testWidgets('staff cannot view reports or manage users', (tester) async {
    await pumpFor(tester, UserRole.staff);

    expect(find.text('Staff account'), findsOneWidget);
    expect(find.text('Allowed'), findsNWidgets(4));
    expect(find.text('Not allowed'), findsNWidgets(2));
  });

  testWidgets('a guest is allowed nothing', (tester) async {
    await pumpFor(tester, UserRole.guest);

    expect(find.text('Guest account'), findsOneWidget);
    expect(find.text('Not allowed'), findsNWidgets(6));
  });
}
