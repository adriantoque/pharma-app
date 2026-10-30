import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/admin/data/repositories/audit_repository.dart';
import 'package:pharmaguide/features/admin/domain/audit_event.dart';
import 'package:pharmaguide/features/admin/presentation/screens/admin_home_screen.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/reports/data/models/expiry_alert.dart';
import 'package:pharmaguide/features/reports/data/models/report_range.dart';
import 'package:pharmaguide/features/reports/data/models/sales_report.dart';
import 'package:pharmaguide/features/reports/data/models/stock_alert.dart';
import 'package:pharmaguide/features/reports/data/repositories/reports_repository.dart';
import 'package:pharmaguide/features/reports/presentation/providers/reports_provider.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_auth_repository.dart';

/// A repository that answers with the fixed figures these tests assert on.
class _FakeReportsRepository implements ReportsRepository {
  _FakeReportsRepository({this.salesReport, this.lowStockAlerts = const []});

  final SalesReport? salesReport;
  final List<StockAlert> lowStockAlerts;

  @override
  Future<SalesReport> getSalesReport(ReportRange range) async =>
      salesReport ?? _emptyReport(range);

  @override
  Future<List<StockAlert>> getLowStockAlerts() async => lowStockAlerts;

  @override
  Future<List<ExpiryAlert>> getExpiryAlerts({int withinDays = 90}) async =>
      const [];

  SalesReport _emptyReport(ReportRange range) => SalesReport(
        range: range,
        generatedAt: DateTime.now(),
        dailySales: const [],
        topSellers: const [],
        categorySales: const [],
        totalRevenue: 0,
        totalOrders: 0,
        totalItems: 0,
        profitMargin: 0.22,
      );
}

class _FakeAuditRepository implements AuditRepository {
  _FakeAuditRepository({this.events = const []});

  final List<AuditEvent> events;

  @override
  Future<void> record({
    required AuditAction action,
    required String actorUid,
    required String actorName,
    required String summary,
    String? targetId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {}

  @override
  Stream<List<AuditEvent>> watchAll() => Stream.value(events);
}

/// Seven days of trade ending today, so the chart has a full week to draw.
SalesReport _weekOfSales() {
  final today = DateTime.now();
  return SalesReport(
    range: ReportRange.week,
    generatedAt: today,
    dailySales: [
      for (var i = 6; i >= 0; i--)
        DailySales(
          date: DateTime(today.year, today.month, today.day - i),
          amount: 100000 + (6 - i) * 25000,
        ),
    ],
    topSellers: const [],
    categorySales: const [],
    totalRevenue: 250000,
    totalOrders: 12,
    totalItems: 30,
    profitMargin: 0.22,
  );
}

const _threeLowStock = [
  StockAlert(name: 'Amoxicillin', currentStock: 2, reorderLevel: 10),
  StockAlert(name: 'Cetirizine', currentStock: 1, reorderLevel: 8),
  StockAlert(name: 'Losartan', currentStock: 4, reorderLevel: 12),
];

void main() {
  late FakeAuthRepository authRepository;
  late AuthProvider auth;
  late ReportsProvider reports;

  setUp(() {
    authRepository = FakeAuthRepository();
    auth = AuthProvider(authRepository);
  });

  tearDown(() {
    auth.dispose();
    reports.dispose();
    authRepository.dispose();
  });

  /// Builds the dashboard against fixed report data.
  ///
  /// The provider is created here rather than in [setUp] because it resolves
  /// its data in the constructor's call chain, so the fake has to be
  /// configured before the provider exists.
  Future<void> pumpDashboard(
    WidgetTester tester, {
    SalesReport? salesReport,
    List<StockAlert> lowStockAlerts = const [],
    List<AuditEvent> events = const [],
  }) async {
    // A tall window so every section of the dashboard is built. The body is a
    // lazy ListView, and on the default 800x600 surface the lower sections are
    // never laid out, so their finders would miss for the wrong reason.
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    reports = ReportsProvider(
      repository: _FakeReportsRepository(
        salesReport: salesReport,
        lowStockAlerts: lowStockAlerts,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ReportsProvider>.value(value: reports),
          Provider<AuditRepository>.value(
            value: _FakeAuditRepository(events: events),
          ),
        ],
        child: const MaterialApp(home: AdminHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders every dashboard section', (tester) async {
    await pumpDashboard(tester, salesReport: _weekOfSales());

    expect(find.text('Welcome back,'), findsOneWidget);
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Low stock'), findsOneWidget);
    expect(find.text('Sales trend'), findsOneWidget);
    expect(find.text('Revenue Growth'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Low stock alerts'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
  });

  testWidgets('the inventory card shows a count, not a peso amount', (
    tester,
  ) async {
    // Three items below reorder level. The card used to render this as
    // currency, so an admin saw "₱0.03" where "3" belonged.
    await pumpDashboard(
      tester,
      salesReport: _weekOfSales(),
      lowStockAlerts: _threeLowStock,
    );

    final inventoryCard = find
        .ancestor(of: find.text('Low stock'), matching: find.byType(Card))
        .first;
    expect(
      find.descendant(of: inventoryCard, matching: find.text('3')),
      findsOneWidget,
    );
    expect(find.text('₱0.03'), findsNothing);
  });

  testWidgets('low stock alerts list the affected medicines', (tester) async {
    await pumpDashboard(
      tester,
      salesReport: _weekOfSales(),
      lowStockAlerts: _threeLowStock,
    );

    expect(find.text('(3 items)'), findsOneWidget);
    expect(find.text('Amoxicillin'), findsOneWidget);
    expect(find.text('Cetirizine'), findsOneWidget);
  });

  testWidgets('the revenue chart shows the week total once data lands', (
    tester,
  ) async {
    await pumpDashboard(tester, salesReport: _weekOfSales());

    // formattedTotalRevenue already carries its own peso sign; the chart used
    // to prefix a second one.
    expect(find.text('₱2,500.00'), findsOneWidget);
    expect(find.text('12 orders'), findsOneWidget);
    expect(find.text('₱₱2,500.00'), findsNothing);
  });

  testWidgets('an empty activity log says so instead of showing a spinner', (
    tester,
  ) async {
    await pumpDashboard(tester, salesReport: _weekOfSales());

    expect(find.text('No activity yet.'), findsOneWidget);
  });

  testWidgets('sign-out asks first and cancelling keeps the session', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsNothing);
    expect(authRepository.logoutCalls, 0);
  });

  testWidgets('confirming sign-out logs the admin out', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(authRepository.logoutCalls, 1);
    expect(find.text('Sign out?'), findsNothing);
  });
}
