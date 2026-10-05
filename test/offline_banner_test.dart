import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/widgets/offline_banner.dart';
import 'package:pharmaguide/features/search/data/sync/sync_status.dart';

void main() {
  Widget buildBanner(SyncStatus status) => MaterialApp(
        home: Scaffold(
          body: OfflineBanner(status: status),
        ),
      );

  group('OfflineBanner', () {
    testWidgets('does nothing when online', (WidgetTester tester) async {
      await tester.pumpWidget(buildBanner(SyncStatus.localOnly));

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.textContaining('Offline'), findsNothing);
    });

    testWidgets('shows offline without pending changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildBanner(const SyncStatus(reachability: Reachability.offline)),
      );

      expect(find.textContaining('Offline'), findsOneWidget);
      expect(find.textContaining('are saved here'), findsNothing);
    });

    testWidgets('says the work is safe when nothing is waiting', (
      WidgetTester tester,
    ) async {
      // The distinction the whole banner exists for: offline with nothing pending
      // means the work is saved, and with writes outstanding it is not yet. A
      // pharmacist closing the app needs to know which of the two they were in.
      await tester.pumpWidget(
        buildBanner(const SyncStatus(reachability: Reachability.offline)),
      );

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
      expect(find.textContaining('Showing the price list'), findsOneWidget);
    });

    testWidgets('shows pending-changes message when offline with writes pending', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildBanner(
          const SyncStatus(
            reachability: Reachability.offline,
            pendingWriteCount: 1,
          ),
        ),
      );

      // A single count is said as "1 change", not "1 changes" -- the count comes
      // from the app's own queue, so it is exact and worth saying exactly.
      expect(find.textContaining('1 change is saved here'), findsOneWidget);
      expect(find.textContaining('will sync when you reconnect'), findsOneWidget);
    });

    testWidgets('pluralises the pending-changes count', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildBanner(
          const SyncStatus(
            reachability: Reachability.offline,
            pendingWriteCount: 4,
          ),
        ),
      );

      expect(find.textContaining('4 changes are saved here'), findsOneWidget);
      expect(find.textContaining('will sync when you reconnect'), findsOneWidget);
    });

    testWidgets('hides again when the connection returns', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildBanner(
          const SyncStatus(
            reachability: Reachability.offline,
            pendingWriteCount: 1,
          ),
        ),
      );
      expect(find.textContaining('Offline'), findsOneWidget);

      await tester.pumpWidget(buildBanner(SyncStatus.localOnly));
      await tester.pump();

      expect(find.textContaining('Offline'), findsNothing);
    });
  });
}