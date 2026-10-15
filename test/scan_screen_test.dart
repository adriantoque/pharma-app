import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/scan/domain/prescription_recognizer.dart';
import 'package:pharmaguide/features/scan/presentation/screens/scan_screen.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_repository.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_prescription_camera.dart';
import 'helpers/fake_prescription_recognizer.dart';

/// Builds the Scan tab with a fake camera and a fake recognizer, so no test
/// depends on a platform channel or a downloaded model.
///
/// The catalogue is injected rather than read from a `MedicineProvider`, which
/// is what lets these tests run without the auth-backed provider chain the real
/// app builds. `Bioflu Tablet` is in the static list, so a scanned line naming
/// it always produces exactly one add button keyed `addBioflu Tablet`.
Future<OrderProvider> pumpScan(
  WidgetTester tester, {
  FakePrescriptionCamera? camera,
  FakePrescriptionRecognizer? recognizer,
  Size surface = const Size(360, 720),
}) async {
  tester.view.physicalSize = surface;
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
          camera: camera ?? FakePrescriptionCamera(),
          recognizer: recognizer ?? FakePrescriptionRecognizer(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return order;
}

/// The single scan button. The controls are a library-private widget, so there
/// is no type to find -- the key is the only handle.
final scanButton = find.byKey(const Key('scanButton'));
final pickPhotoButton = find.byKey(const Key('pickPhotoButton'));
final retryCameraButton = find.byKey(const Key('retryCameraButton'));
final retryReadingButton = find.byKey(const Key('retryReadingButton'));

void main() {
  group('the camera', () {
    testWidgets('opens and offers both ways in', (tester) async {
      final camera = FakePrescriptionCamera();
      await pumpScan(tester, camera: camera);

      expect(camera.initializeCalls, 1);
      expect(find.text('Scan it'), findsOneWidget);
      expect(
        find.byTooltip('Pick a prescription from the gallery'),
        findsOneWidget,
      );
      // The gate is gone now that the preview is up.
      expect(find.text('Opening the camera…'), findsNothing);
      expect(find.text('No preview'), findsNothing);
    });

    testWidgets('a refused camera offers a retry that works', (tester) async {
      final camera = FakePrescriptionCamera(
        initializeError: PrescriptionRecognitionException(
          'The camera permission was refused.',
          isPermissionDenied: true,
        ),
      );
      await pumpScan(tester, camera: camera);

      expect(find.text('The camera permission was refused.'), findsOneWidget);
      expect(find.text('Opening the camera…'), findsNothing);
      // Nothing can be scanned without a preview, so the button is disabled.
      expect(tester.widget<OutlinedButton>(scanButton).onPressed, isNull);

      camera.initializeError = null;
      await tester.tap(retryCameraButton);
      await tester.pumpAndSettle();

      expect(camera.initializeCalls, 2);
      expect(find.text('Scan it'), findsOneWidget);
    });

    testWidgets('a capture failure offers a retry', (tester) async {
      final camera = FakePrescriptionCamera();
      await pumpScan(tester, camera: camera);

      camera.takePictureError = PrescriptionRecognitionException(
        'The frame could not be captured.',
      );
      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(find.text('The frame could not be captured.'), findsOneWidget);
      expect(retryReadingButton, findsOneWidget);

      camera.takePictureError = null;
      await tester.tap(retryReadingButton);
      await tester.pumpAndSettle();

      // The retry took the picture and the recognizer had nothing to say.
      expect(find.text('The frame could not be captured.'), findsNothing);
      expect(find.text('Nothing read yet.'), findsNothing);
    });
  });

  group('a platform with no camera', () {
    testWidgets('says so and drops the controls', (tester) async {
      await pumpScan(
        tester,
        camera: FakePrescriptionCamera(isSupported: false),
      );

      expect(
        find.textContaining('Camera text recognition is not available'),
        findsOneWidget,
      );
      expect(scanButton, findsNothing);
      expect(pickPhotoButton, findsNothing);
    });
  });

  group('reading a prescription', () {
    testWidgets('shows every line it read, numbered from one', (tester) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Bioflu Tablet', 'Kremil-S Tablet'),
      );
      await pumpScan(
        tester,
        recognizer: recognizer,
        // The results list shares the screen with a 300px preview, so a second
        // line card falls below the fold on a short phone.
        surface: const Size(360, 1200),
      );

      expect(find.textContaining('Nothing read yet.'), findsOneWidget);

      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(find.text('Line 1: "Bioflu Tablet"'), findsOneWidget);
      expect(find.text('Line 2: "Kremil-S Tablet"'), findsOneWidget);
      expect(recognizer.recognizeCalls, hasLength(1));
    });

    testWidgets('a blank line is called unreadable rather than shown empty', (
      tester,
    ) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: [
          const RecognizedLine('Bioflu Tablet'),
          const RecognizedLine(''),
        ],
      );
      await pumpScan(
        tester,
        recognizer: recognizer,
        surface: const Size(360, 1200),
      );

      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(find.text('Line 2: nothing readable'), findsOneWidget);
    });

    testWidgets('the button reads as busy until the recognizer answers', (
      tester,
    ) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Bioflu Tablet'),
        blockRecognize: true,
      );
      await pumpScan(tester, recognizer: recognizer);

      await tester.tap(scanButton);
      await tester.pump();

      expect(find.text('Reading…'), findsOneWidget);
      expect(find.text('Line 1: "Bioflu Tablet"'), findsNothing);

      recognizer.completeRecognize();
      await tester.pumpAndSettle();

      expect(find.text('Reading…'), findsNothing);
      expect(find.text('Line 1: "Bioflu Tablet"'), findsOneWidget);
    });

    testWidgets('a corrected line is matched again without re-reading', (
      tester,
    ) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('nonsense that matches nothing'),
      );
      await pumpScan(tester, recognizer: recognizer);

      await tester.tap(scanButton);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No medicine in the price list looks like that.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('editReading0')));
      await tester.pumpAndSettle();
      expect(find.text('What it said'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Bioflu Tablet');
      await tester.tap(find.text('Use this'));
      await tester.pumpAndSettle();

      expect(find.text('Line 1: "Bioflu Tablet"'), findsOneWidget);
      // The photo was read once; the fix went through the matcher only.
      expect(recognizer.recognizeCalls, hasLength(1));
    });
  });

  group('when reading fails', () {
    testWidgets('a missing model explains it needs a connection', (
      tester,
    ) async {
      final recognizer = FakePrescriptionRecognizer(
        recognizeError: PrescriptionRecognitionException(
          'The prescription could not be read.',
          isOffline: true,
        ),
      );
      await pumpScan(tester, recognizer: recognizer);

      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Waiting for a connection'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('any other failure offers a plain retry', (tester) async {
      final recognizer = FakePrescriptionRecognizer(
        recognizeError: PrescriptionRecognitionException(
          'Text recognition is not available on this device.',
          isUnsupportedPlatform: true,
        ),
      );
      await pumpScan(tester, recognizer: recognizer);

      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Text recognition is not available on this device.'),
        findsOneWidget,
      );
      expect(find.textContaining('Waiting for a connection'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('the gallery fallback', () {
    testWidgets('reads a picked photo', (tester) async {
      final camera = FakePrescriptionCamera(galleryBytes: Uint8List(64));
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Kremil-S Tablet'),
      );
      await pumpScan(tester, camera: camera, recognizer: recognizer);

      await tester.tap(pickPhotoButton);
      await tester.pumpAndSettle();

      expect(recognizer.recognizeCalls, hasLength(1));
      expect(find.text('Line 1: "Kremil-S Tablet"'), findsOneWidget);
    });

    testWidgets('backing out changes nothing and does not crash', (
      tester,
    ) async {
      final camera = FakePrescriptionCamera(galleryBytes: null);
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Kremil-S Tablet'),
      );
      await pumpScan(tester, camera: camera, recognizer: recognizer);

      await tester.tap(pickPhotoButton);
      await tester.pumpAndSettle();

      expect(recognizer.recognizeCalls, isEmpty);
      expect(find.textContaining('Nothing read yet.'), findsOneWidget);
    });
  });

  group('adding a suggestion to the order', () {
    testWidgets('goes through the quantity sheet and confirms', (tester) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Bioflu Tablet'),
      );
      final order = await pumpScan(tester, recognizer: recognizer);

      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      // Scoped to the key: the reading is an exact name, so exactly one add
      // button is offered.
      await tester.tap(find.byKey(const Key('addBioflu Tablet')));
      await tester.pumpAndSettle();

      expect(find.text('Add to order'), findsOneWidget);
      await tester.tap(find.text('Add to order'));
      await tester.pumpAndSettle();

      expect(find.text('Added 1 × Bioflu Tablet'), findsOneWidget);
      expect(order.itemCount, 1);
    });

    testWidgets('dismissing the sheet adds nothing', (tester) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Bioflu Tablet'),
      );
      final order = await pumpScan(tester, recognizer: recognizer);

      await tester.tap(scanButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addBioflu Tablet')));
      await tester.pumpAndSettle();

      // Tapping the barrier is how the sheet is dismissed.
      await tester.tapAt(const Offset(180, 60));
      await tester.pumpAndSettle();

      expect(order.isEmpty, isTrue);
      expect(find.text('Add to order'), findsNothing);
    });
  });

  testWidgets('the tab releases the camera and recognizer it was given', (
    tester,
  ) async {
    final camera = FakePrescriptionCamera();
    final recognizer = FakePrescriptionRecognizer();
    await pumpScan(tester, camera: camera, recognizer: recognizer);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(camera.disposed, isTrue);
    expect(recognizer.disposed, isTrue);
  });
}
