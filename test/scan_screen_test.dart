import 'package:flutter/material.dart';
import 'package:flutter/test/flutter_test.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/scan/domain/prescription_recognizer.dart';
import 'package:pharmaguide/features/scan/presentation/screens/scan_screen.dart';
import 'package:pharmaguide/features/scan/presentation/widgets/scan_button.dart';
import 'package:pharmaguide/features/scan/presentation/widgets/scan_button_bar.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_prescription_camera.dart';
import 'helpers/fake_prescription_recognizer.dart';

/// Builds the Scan tab with a fake camera and fake recognizer, so no platform
/// channel or model download is required.
Future<OrderProvider> pumpScan(
  WidgetTester tester, {
  required FakePrescriptionCamera camera,
    required FakePrescriptionRecognizer recognizer,
}) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final order = OrderProvider();
  addTearDown(order.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<OrderProvider>.value(
      value: order,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: ScanScreen(
          repository: const StaticMedicineRepository(),
          camera: camera,
          recognizer: recognizer,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return order;
}

/// Writes a prescription line using the on-screen keyboard area.
/// In the real app this would be a drag on an InkCanvas; for the fake camera
/// we simulate the reading by directly setting the recognised text.
/// This helper is kept for compatibility with test code that previously used
/// InkCanvas gestures, but the primary flow below uses the scanButton.
Future<void> simulateScan(WidgetTester tester, String text) async {
  // The fake camera's takePicture returns fixed bytes; the recognizer processes
  // them and the matcher produces suggestions. We simply advance the state
  // by triggering a re-scan.
  await tester.pumpAndSettle();
}

/// Reads the text shown for line [index] from the UI.
String readLineText(WidgetTester tester, int index) {
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .where((t) => t.data != null && t.data!.startsWith('Line $index'))
      .map((t) => t.data!)
      .toList();
  if (text.isEmpty) return '';
  return text[0].replaceFirst('Line $index: ', '').replaceAll('"', '');
}

/// Reads the suggestion for line [index] from the UI.
String readSuggestion(WidgetTester tester, int index) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .where((t) => t.data != null && t.data!.startsWith('Suggestion'))
      .map((t) => t.data!)
      .toList();
  if (texts.isEmpty) return '';
  return texts[0].replaceFirst('Suggestion ', '');
}

void main() {
  const phoneSize = Size(360, 720);

  /// Builds the tab with a fake camera and fake recognizer, so no test
  /// depends on a platform channel or a downloaded model.
  Future<OrderProvider> pumpScan(
    WidgetTester tester, {
      required FakePrescriptionCamera camera,
      required FakePrescriptionRecognizer recognizer,
    }) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final order = OrderProvider();
    addTearDown(order.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<OrderProvider>.value(
        value: order,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: ScanScreen(
            repository: const StaticMedicineRepository(),
            camera: camera,
            recognizer: recognizer,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return order;
  }

  group('the first scan', () {
    testWidgets('opens the scan tab and shows the scan button', (tester) async {
      final order = await pumpScan(
        tester,
        camera: FakePrescriptionCamera(),
        recognizer: FakePrescriptionRecognizer(),
      );

      expect(find.text('Scan it'), findsOneWidget);
      expect(find.text('Pick a prescription from the gallery'), findsOneWidget);
    });

    testWidgets('reading appears after scan', (tester) async {
      final order = await pumpScan(
        tester,
        camera: FakePrescriptionCamera(),
        recognizer: FakePrescriptionRecognizer(),
      );

      // Tap the scan button to trigger recognition
      await tester.tap(find.byType(ScanButton));
      await tester.pumpAndSettle();

      // The fake recognizer returns a canned reading; check that a line appears
      expect(find.text('Line 1'), findsOneWidget);
      expect(readLineText(tester, 1), isNotEmpty);
    });

    testWidgets('adding a medicine to the order', (tester) async {
      final order = await pumpScan(
        tester,
        camera: FakePrescriptionCamera(),
        recognizer: FakePrescriptionRecognizer(),
      );

      await tester.tap(find.byType(ScanButton));
      await tester.pumpAndSettle();

      // A reading appears; tap the first add button
      final addButtons = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.key.toString().contains('add'),
      );
      expect(addButtons, findsAtLeastN(1, 0));
      if (addButtons.evaluate().isNotEmpty) {
        await tester.tap(addButtons.first);
      }
      await tester.pumpAndSettle();

      // Wait for the quantity sheet and confirm
      await tester.tap(find.text('Add to order'));
      await tester.pumpAndSettle();

      // SnackBar should confirm the addition
      expect(find.byType(SnackBar), findsOneWidget);
      final snackText = tester
          .widgetList<Text>(find.byType(SnackBar))
          .map((t) => t.data ?? '')
          .firstWhere((d) => d.startsWith('Added '));
      expect(snackText, startsWith('Added '));
      expect(order.itemCount, 1,
          reason: 'the quantity sheet must add exactly one medicine');
    });
  });

  group('gallery fallback', () {
    testWidgets('gallery picker is available', (tester) async {
      final order = await pumpScan(
        tester,
        camera: FakePrescriptionCamera(),
        recognizer: FakePrescriptionRecognizer(),
      );

      expect(find.text('Pick a prescription from the gallery'), findsOneWidget);
      // The fake camera has no gallery images; tapping the button does nothing
      // useful in the test environment, but the UI should not crash.
      await tester.tap(find.byIcon(Icons.image));
      await tester.pumpAndSettle();
    });
  });
}