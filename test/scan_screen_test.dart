import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/scan/domain/prescription_recognizer.dart';
import 'package:pharmaguide/features/scan/presentation/screens/scan_screen.dart';
import 'package:pharmaguide/features/scan/presentation/widgets/ink_canvas.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_prescription_recognizer.dart';

void main() {
  const phoneSize = Size(360, 720);

  /// Builds the tab with a fake recognizer standing in for ML Kit, so no test
  /// depends on a downloaded model or on a platform channel.
  Future<OrderProvider> pumpScan(
    WidgetTester tester, {
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
          home: ScanScreen(recognizer: recognizer),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return order;
  }

  Future<void> writeAWord(WidgetTester tester) async {
    await tester.drag(find.byType(InkCanvas), const Offset(60, 20));
    await tester.pump();
  }

  Finder canvas = find.byType(InkCanvas);

  group('the first opening', () {
    testWidgets('explains what the tab is for', (tester) async {
      await pumpScan(
        tester,
        recognizer: FakePrescriptionRecognizer(),
      );

      expect(
        find.text('Write the prescription, then read it'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Nothing read yet. Write a medicine name on the lines above, or '
          'search for one below.',
        ),
        findsOneWidget,
      );
      expect(find.text('Scan'), findsOneWidget);
    });

    testWidgets('shows the canvas when the model is already there', (
      tester,
    ) async {
      await pumpScan(
        tester,
        recognizer: FakePrescriptionRecognizer(),
      );

      expect(canvas, findsOneWidget);
      expect(find.text('Download the handwriting model'), findsNothing);
    });

    testWidgets('a disarmed undo and clear and a disabled read at first', (
      tester,
    ) async {
      await pumpScan(
        tester,
        recognizer: FakePrescriptionRecognizer(),
      );

      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('undoStroke')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('clearCanvas')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('recognizeButton')))
            .onPressed,
        isNull,
      );
    });
  });

  group('the model gate', () {
    testWidgets('offers a download when the model is missing', (
      tester,
    ) async {
      await pumpScan(
        tester,
        recognizer: FakePrescriptionRecognizer(modelReady: false),
      );

      expect(canvas, findsNothing);
      expect(find.text('Download the handwriting model'), findsOneWidget);
      expect(
        find.textContaining('About 20 MB, once'),
        findsOneWidget,
      );
    });

    testWidgets('downloading unlocks the canvas', (tester) async {
      final recognizer = FakePrescriptionRecognizer(modelReady: false);
      await pumpScan(tester, recognizer: recognizer);

      await tester.tap(find.byKey(const Key('downloadModelButton')));
      await tester.pumpAndSettle();

      expect(recognizer.ensureModelCalls, 1);
      expect(recognizer.modelReady, isTrue);
      expect(canvas, findsOneWidget);
      expect(find.text('Download the handwriting model'), findsNothing);
    });

    testWidgets('a download is never started on its own', (tester) async {
      final recognizer = FakePrescriptionRecognizer(modelReady: false);
      await pumpScan(tester, recognizer: recognizer);

      expect(recognizer.ensureModelCalls, 0);
    });

    testWidgets('a failed download is explained and can be retried', (
      tester,
    ) async {
      final recognizer = FakePrescriptionRecognizer(
        modelReady: false,
        ensureModelError: PrescriptionRecognitionException(
          'The handwriting model could not be downloaded.',
          isOffline: true,
        ),
      );
      await pumpScan(tester, recognizer: recognizer);

      await tester.tap(find.byKey(const Key('downloadModelButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('The handwriting model could not be downloaded.'),
        findsOneWidget,
      );
      expect(canvas, findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // The retry checks again rather than staring at the error, and the model
      // is still missing, so the download card is back.
      expect(canvas, findsNothing);
      expect(find.text('Download the handwriting model'), findsOneWidget);
    });

    testWidgets('an unsupported platform explains itself but keeps search', (
      tester,
    ) async {
      await pumpScan(
        tester,
        recognizer: FakePrescriptionRecognizer(isSupported: false),
      );

      expect(
        find.textContaining('not available on this platform'),
        findsOneWidget,
      );
      expect(canvas, findsNothing);

      await tester.enterText(
        find.byKey(const Key('prescriptionSearchField')),
        'Biogesic',
      );
      await tester.pump();

      expect(find.byKey(const Key('addBiogesic')), findsOneWidget);
    });
  });

  group('drawing', () {
    testWidgets('a drag writes a stroke and arms undo and clear', (
      tester,
    ) async {
      await pumpScan(
        tester,
        recognizer: FakePrescriptionRecognizer(),
      );

      await writeAWord(tester);

      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('undoStroke')))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('clearCanvas')))
            .onPressed,
        isNotNull,
      );
      expect(
        find.text(
          'Press "Read it" to see what this says.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('undo removes the last stroke', (tester) async {
      await pumpScan(
        tester,
        recognizer: FakePrescriptionRecognizer(),
      );

      await writeAWord(tester);
      await writeAWord(tester);

      await tester.tap(find.byKey(const Key('undoStroke')));
      await tester.pump();

      // One stroke left: undo is still armed, and one more undoes everything.
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('undoStroke')))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('undoStroke')));
      await tester.pump();

      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('undoStroke')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('clear empties the canvas in one tap', (tester) async {
      await pumpScan(
        tester,
        recognizer: FakePrescriptionRecognizer(),
      );

      await writeAWord(tester);
      await writeAWord(tester);

      await tester.tap(find.byKey(const Key('clearCanvas')));
      await tester.pump();

      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('clearCanvas')))
            .onPressed,
        isNull,
      );
    });
  });

  group('reading', () {
    testWidgets('sends the ink and shows what each line could be', (
      tester,
    ) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Amox 500mg', 'Biogesic'),
      );
      await pumpScan(tester, recognizer: recognizer);

      await writeAWord(tester);
      await tester.tap(find.byKey(const Key('recognizeButton')));
      await tester.pumpAndSettle();

      expect(recognizer.recognizeCalls, hasLength(1));
      expect(find.text('Line 1: "Amox 500mg"'), findsOneWidget);
      expect(find.text('Line 2: "Biogesic"'), findsOneWidget);
      expect(find.byKey(const Key('addAmox 500mg')), findsOneWidget);
      expect(find.byKey(const Key('addBiogesic')), findsOneWidget);
    });

    testWidgets('shows a reading label while the model works', (
      tester,
    ) async {
      final recognizer = FakePrescriptionRecognizer(
        blockRecognize: true,
        readings: readingsOf('Biogesic'),
      );
      await pumpScan(tester, recognizer: recognizer);

      await writeAWord(tester);
      await tester.tap(find.byKey(const Key('recognizeButton')));
      await tester.pump();

      // A label rather than a spinner, so the frame scheduler can still settle
      // while a read is in flight.
      expect(find.text('Reading…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('recognizeButton')))
            .onPressed,
        isNull,
      );

      recognizer.completeRecognize();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('addBiogesic')), findsOneWidget);
    });

    testWidgets('explains a read that found no medicines', (tester) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('zzz qqq'),
      );
      await pumpScan(tester, recognizer: recognizer);

      await writeAWord(tester);
      await tester.tap(find.byKey(const Key('recognizeButton')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No medicine in the price list looks like that. Try Fix, or search '
          'below.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a read that fails keeps the canvas usable', (tester) async {
      final recognizer = FakePrescriptionRecognizer(
        recognizeError: PrescriptionRecognitionException(
          'The handwriting could not be read.',
        ),
      );
      await pumpScan(tester, recognizer: recognizer);

      await writeAWord(tester);
      await tester.tap(find.byKey(const Key('recognizeButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('The handwriting could not be read.'),
        findsOneWidget,
      );
      expect(canvas, findsOneWidget);

      // The retry reaches the recognizer again, and a second failure leaves the
      // error up rather than losing the ink.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(recognizer.recognizeCalls, hasLength(2));
    });

    testWidgets('a misread line can be corrected by hand', (tester) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Amox 500mg'),
      );
      await pumpScan(tester, recognizer: recognizer);

      await writeAWord(tester);
      await tester.tap(find.byKey(const Key('recognizeButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('editReading0')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Biogesic',
      );
      await tester.tap(find.text('Use this'));
      await tester.pumpAndSettle();

      expect(find.text('Line 1: "Biogesic"'), findsOneWidget);
      expect(find.byKey(const Key('addBiogesic')), findsOneWidget);
    });
  });

  group('adding to the order', () {
    testWidgets('nothing is added without a tap', (tester) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Biogesic'),
      );
      final order = await pumpScan(tester, recognizer: recognizer);

      await writeAWord(tester);
      await tester.tap(find.byKey(const Key('recognizeButton')));
      await tester.pumpAndSettle();

      expect(order.itemCount, 0);
    });

    testWidgets('a tapped suggestion goes through the quantity sheet', (
      tester,
    ) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Biogesic'),
      );
      final order = await pumpScan(tester, recognizer: recognizer);

      await writeAWord(tester);
      await tester.tap(find.byKey(const Key('recognizeButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addBiogesic')));
      await tester.pumpAndSettle();

      expect(find.text('Add to order'), findsOneWidget);
      await tester.tap(find.text('Add to order'));
      await tester.pumpAndSettle();

      expect(order.quantityOf(
        const MedicineModel(name: 'Biogesic', priceCentavos: 600, stock: 41),
      ), 1);
      expect(find.text('Added 1 × Biogesic'), findsOneWidget);
    });
  });
}