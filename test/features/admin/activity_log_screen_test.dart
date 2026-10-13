import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/admin/domain/audit_event.dart';
import 'package:pharmaguide/features/admin/presentation/screens/activity_log_screen.dart';

import '../../helpers/fake_audit_repository.dart';

void main() {
  final userEvent = AuditEvent(
    id: '1',
    action: AuditAction.userCreated,
    actorUid: 'u1',
    actorName: 'Maria',
    summary: 'Created user Juan Dela Cruz (staff)',
    at: DateTime(2026, 1, 1, 9),
  );
  final settingsEvent = AuditEvent(
    id: '2',
    action: AuditAction.settingsUpdated,
    actorUid: 'u1',
    actorName: 'Maria',
    summary: 'Updated store settings',
    at: DateTime(2026, 1, 1, 10),
  );

  late FakeAuditRepository repository;

  setUp(() => repository = FakeAuditRepository());
  tearDown(() => repository.dispose());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: ActivityLogScreen(repository: repository),
      ),
    );
  }

  testWidgets('lists the entries it is given', (tester) async {
    await pump(tester);
    repository.emit([userEvent, settingsEvent]);
    await tester.pump();

    expect(find.text('Created user Juan Dela Cruz (staff)'), findsOneWidget);
    expect(find.text('Updated store settings'), findsOneWidget);
  });

  testWidgets('filters to one category when a chip is tapped', (tester) async {
    await pump(tester);
    repository.emit([userEvent, settingsEvent]);
    await tester.pump();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Updated store settings'), findsOneWidget);
    expect(find.text('Created user Juan Dela Cruz (staff)'), findsNothing);
  });

  testWidgets('explains an empty log', (tester) async {
    await pump(tester);
    repository.emit(const []);
    await tester.pump();

    expect(find.text('No activity yet'), findsOneWidget);
  });
}
