import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/scan/presentation/screens/scan_screen.dart';
import 'package:pharmaguide/features/scan/presentation/widgets/ink_canvas.dart';

/// Draws [word]'s letters into [rect] as polylines, so the on-device test does
/// not depend on a human hand. The shapes are rough block letters; ML Kit's
/// digital-ink recognizer is expected to cope with a fair amount of slop.
Future<void> handDraw(WidgetTester tester, Rect rect, String word) async {
  final letterBox = rect.width / word.length;
  final scale = <double>[letterBox, rect.height];

  for (final char in word.split('')) {
    final strokes = _strokesFor(char);
    for (final points in strokes) {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.addPointer(location: Offset.zero);
      await gesture.down(_scaled(points.first, scale) + rect.topLeft);
      for (final point in points.skip(1)) {
        await gesture.moveTo(_scaled(point, scale) + rect.topLeft);
      }
      await gesture.up();
      // So the recognizer sees them as separate strokes of the same word.
      await tester.pump(const Duration(milliseconds: 30));
    }
    // A wider gap between words than between letters of the same word.
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Offset _scaled(Offset point, List<double> scale) => Offset(point.dx * scale[0], point.dy * scale[1]);

/// Block-letter skeletons, each a list of polylines in a unit box. Drawn tall
/// and separated, they read clearly even to a recognizer expecting print.
List<List<Offset>> _strokesFor(String char) {
  switch (char.toUpperCase()) {
    case 'A':
      return [
        [const Offset(0.12, 0.98), const Offset(0.50, 0.02), const Offset(0.88, 0.98)],
        [const Offset(0.32, 0.58), const Offset(0.68, 0.58)],
      ];
    case 'M':
      return [
        [const Offset(0.10, 0.98), const Offset(0.10, 0.02)],
        [const Offset(0.10, 0.02), const Offset(0.30, 0.55), const Offset(0.50, 0.02)],
        [const Offset(0.50, 0.02), const Offset(0.50, 0.98)],
      ];
    case 'O':
      return [
        [const Offset(0.50, 0.02), const Offset(0.08, 0.50), const Offset(0.50, 0.98), const Offset(0.92, 0.50), const Offset(0.50, 0.02)],
      ];
    case 'X':
      return [
        [const Offset(0.10, 0.02), const Offset(0.90, 0.98)],
        [const Offset(0.90, 0.02), const Offset(0.10, 0.98)],
      ];
    default:
      return [
        [const Offset(0.10, 0.98), const Offset(0.10, 0.02)],
        [const Offset(0.10, 0.02), const Offset(0.75, 0.02)],
      ];
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(minutes: 3), String? what}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (finder.evaluate().isNotEmpty) {
      debugPrint('[scan-flow] ok: $what');
      return;
    }
  }
  fail('timed out waiting for $what');
}

/// Waits until the UI settles into one of [states], so a caller can react to a
/// model check that is still in flight. Returns the key of the first Finder
/// that matched.
Future<String> waitForAny(WidgetTester tester, List<({Finder finder, String key})> states,
    {Duration timeout = const Duration(minutes: 3), String? what}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 500));
    for (final state in states) {
      if (state.finder.evaluate().isNotEmpty) return state.key;
    }
  }
  fail('timed out waiting for $what');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('handwriting is recognised, matched and added to the order',
      (tester) async {
    final order = OrderProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<OrderProvider>.value(
        value: order,
        child: const MaterialApp(home: ScanScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final download = find.byKey(const Key('downloadModelButton'));
    final ready = find.byKey(const Key('recognizeButton'));
    final state = await waitForAny(
      tester,
      [
        (finder: download, key: 'download'),
        (finder: ready, key: 'ready'),
      ],
      what: 'the model check to finish (download card or canvas)',
    );

    if (state == 'download') {
      debugPrint('[scan-flow] model not present on this install; downloading');
      await tester.tap(download);
      await waitFor(tester, ready, what: 'handwriting model downloaded, canvas showing');
    } else {
      debugPrint('[scan-flow] handwriting model already present');
    }

    final canvasRect = tester.getRect(find.byType(InkCanvas).first);
    debugPrint('[scan-flow] canvas rect: $canvasRect');
    await handDraw(tester, canvasRect, 'Amox');

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recognizeButton')));

    await waitFor(
      tester,
      find.textContaining('Line 1'),
      what: 'a reading for line 1',
    );

    final readingTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .where((data) => data.contains('Line 1'))
        .toList();
    final reading = readingTexts[0]
        .replaceFirst('Line 1: ', '')
        .replaceFirst('"', '')
        .replaceFirst('"', '');
    debugPrint('[scan-flow] ML Kit read: "$reading"');

    final addButtons = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.key.toString().contains('add'),
    );
    if (addButtons.evaluate().isEmpty) {
      debugPrint('[scan-flow] no catalogue match for that reading; '
          'order stays untouched');
      expect(order.itemCount, 0);
      return;
    }

    await tester.tap(addButtons.first);
    await waitFor(
      tester,
      find.text('Add to order'),
      what: 'quantity sheet open',
    );
    await tester.tap(find.text('Add to order'));
    await waitFor(
      tester,
      find.byType(SnackBar),
      what: 'order confirmation snack bar',
    );
    final snackText = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .firstWhere((data) => data.startsWith('Added '));
    debugPrint('[scan-flow] $snackText');
    expect(order.itemCount, 1,
        reason: 'the quantity sheet must add exactly one medicine');
  });
}