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
      expect(find.textContaining('Changes are saved'), findsNothing);
    });

    testWidgets('shows pending-changes message when offline with writes pending',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildBanner(
          const SyncStatus(
            reachability: Reachability.offline,
            pendingWriteCount: 1,
          ),
        ),
      );

      expect(find.textContaining('Changes are saved'), findsOneWidget);
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