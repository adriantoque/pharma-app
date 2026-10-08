import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/bootstrap/bootstrap_failure_screen.dart';
import 'package:pharmaguide/bootstrap/firebase_bootstrap.dart';
import 'package:pharmaguide/bootstrap/splash_screen.dart';
import 'package:pharmaguide/main.dart';

void main() {
  group('SplashScreen', () {
    testWidgets('shows the brand mark and a progress indicator', (
      tester,
    ) async {
      await tester.pumpWidget(const SplashScreen());
      await tester.pump();

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text("Wilma\nPharmacy's"), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('opaque, because the theme scaffold background is clear', (
      tester,
    ) async {
      await tester.pumpWidget(const SplashScreen());
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, isNot(Colors.transparent));
    });
  });

  // Note: only the failure branch is exercised below. A *successful* result
  // builds the real MultiProvider, which constructs FirebaseAuthRepository ->
  // FirebaseAuth.instance, and that throws [core/no-app] under `flutter test`
  // with no Firebase initialised. The success branch is covered indirectly by
  // the rest of the suite, which pumps App against a fake repository.
  //
  // Both branches share _revealWhenReady and the AnimatedSwitcher, so driving
  // the transition with a failure result still tests the timing behaviour.
  group('PharmaGuideApp bootstrap', () {
    testWidgets('shows the splash until the bootstrap resolves', (tester) async {
      final completer = Completer<FirebaseBootstrapResult>();

      await tester.pumpWidget(PharmaGuideApp(bootstrap: completer.future));
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(BootstrapFailureScreen), findsNothing);

      completer.complete(
        const FirebaseBootstrapResult.failure('No config here.'),
      );

      // Past the minimum-splash hold and the cross-fade.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(BootstrapFailureScreen), findsOneWidget);
    });

    testWidgets('routes a failed bootstrap to the failure screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        PharmaGuideApp(
          bootstrap: Future.value(
            const FirebaseBootstrapResult.failure('No config here.'),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(BootstrapFailureScreen), findsOneWidget);
      expect(find.text('No config here.'), findsOneWidget);
    });

    testWidgets('the splash is held briefly so it cannot flash', (
      tester,
    ) async {
      // An already-resolved future is the worst case: without the hold the
      // splash would exist for a single frame and strobe.
      await tester.pumpWidget(
        PharmaGuideApp(
          bootstrap: Future.value(const FirebaseBootstrapResult.failure('x')),
        ),
      );
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SplashScreen), findsOneWidget);

      // Draining the hold also leaves no pending timer behind, which the test
      // framework asserts on at teardown.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('a bootstrap that never completes keeps the splash up', (
      tester,
    ) async {
      await tester.pumpWidget(
        PharmaGuideApp(bootstrap: Completer<FirebaseBootstrapResult>().future),
      );
      await tester.pump(const Duration(seconds: 5));

      expect(find.byType(SplashScreen), findsOneWidget);
    });
  });
}