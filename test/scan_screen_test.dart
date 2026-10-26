import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/scan/domain/prescription_recognizer.dart';
import 'package:pharmaguide/features/scan/presentation/screens/scan_screen.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
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
  MedicineRepository? repository,
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
          repository: repository ?? const StaticMedicineRepository(),
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

/// The live preview, which is what grows and shrinks as the result takes the
/// screen. The fake camera paints it one particular colour, so the colour is
/// the handle rather than a key the production widget would only carry for
/// the tests' sake.
final previewBox = find.byWidgetPredicate(
  (widget) => widget is ColoredBox && widget.color == const Color(0xFF103B21),
);

void main() {
  group('the camera', () {
    testWidgets('opens and offers both ways in', (tester) async {
      final camera = FakePrescriptionCamera();
      await pumpScan(tester, camera: camera);

      expect(camera.initializeCalls, 1);
      expect(find.text('Scan it'), findsOneWidget);
      expect(
        find.byTooltip('Pick a prescription from the gallery'),
        findsNothing,
      );
      // The gallery pick is a labelled button now: a tooltip unreachable on
      // touch was not a promise the control could keep.
      expect(find.text('From photos'), findsOneWidget);
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

  group('the scan result', () {
    testWidgets('a successful read collapses the preview and heads it', (
      tester,
    ) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Bioflu Tablet'),
      );
      await pumpScan(tester, recognizer: recognizer);

      // The full preview, before anything was read.
      expect(tester.getSize(previewBox).height, 300);

      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      // The preview is a strip now, and the result opens with its counts.
      expect(find.text('Scan result · 1 line · 1 match'), findsOneWidget);
      expect(tester.getSize(previewBox).height, 140);
      expect(find.text('Line 1: "Bioflu Tablet"'), findsOneWidget);
      expect(find.byKey(const Key('addBioflu Tablet')), findsOneWidget);
    });

    testWidgets('Scan again hands the room back to the camera', (tester) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Bioflu Tablet'),
      );
      await pumpScan(tester, recognizer: recognizer);

      await tester.tap(scanButton);
      await tester.pumpAndSettle();
      expect(find.text('Scan result · 1 line · 1 match'), findsOneWidget);

      await tester.tap(find.byKey(const Key('scanAgainButton')));
      await tester.pumpAndSettle();

      expect(find.text('Scan result · 1 line · 1 match'), findsNothing);
      expect(tester.getSize(previewBox).height, 300);
      // Hidden, not thrown away: the reading is still in state.
      expect(
        find.text('Results hidden — tap Scan it to read a new photo.'),
        findsOneWidget,
      );
      expect(recognizer.recognizeCalls, hasLength(1));
    });

    testWidgets('a photo that names nothing keeps the preview up', (
      tester,
    ) async {
      final recognizer = FakePrescriptionRecognizer(); // no readings at all
      await pumpScan(tester, recognizer: recognizer);

      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      // Nothing was read, so there is no result to hand the room to.
      expect(tester.getSize(previewBox).height, 300);
      expect(find.textContaining('Scan result'), findsNothing);
      expect(find.textContaining('Nothing read yet.'), findsOneWidget);
    });

    testWidgets('the info dialog quotes a number, not a fixed word', (
      tester,
    ) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Bioflu Tablet'),
      );
      await pumpScan(tester, recognizer: recognizer);

      await tester.tap(scanButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detailsBioflu Tablet')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(RegExp('Match confidence: [0-9]+%')),
        findsOneWidget,
      );
      expect(find.text('Match confidence: high'), findsNothing);
    });

    testWidgets('says how many are already in the order', (tester) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Bioflu Tablet'),
      );
      final order = await pumpScan(tester, recognizer: recognizer);

      await tester.tap(scanButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('in cart'), findsNothing);

      await tester.tap(find.byKey(const Key('addBioflu Tablet')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to order'));
      await tester.pumpAndSettle();

      expect(find.text('×1 in cart'), findsOneWidget);
      expect(order.itemCount, 1);
    });

    testWidgets('a line that needs a prescription says so', (tester) async {
      final recognizer = FakePrescriptionRecognizer(
        readings: readingsOf('Bioflu Tablet'),
      );
      await pumpScan(
        tester,
        recognizer: recognizer,
        repository: const _RxCatalogue(),
      );

      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(find.text('Rx required'), findsOneWidget);
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

  group('the committed sheet', () {
    testWidgets('a steady read opens it on its own and adds nothing', (
      tester,
    ) async {
      final camera = FakePrescriptionCamera(supportsLive: true);
      final recognizer = FakePrescriptionRecognizer(
        supportsFrameRecognition: true,
        frameReadings: readingsOf('Bioflu Tablet'),
      );
      final staged = await pumpLiveScan(
        tester,
        camera: camera,
        recognizer: recognizer,
      );

      await deliverFrames(tester, camera, 3);
      await tester.pumpAndSettle();

      // The read committed itself into the sheet, with the header counting it
      // like the deliberate flow would.
      expect(recognizer.frameCalls, 3);
      expect(find.textContaining('Scan result ·'), findsOneWidget);
      expect(find.text('Line 1: "Bioflu Tablet"'), findsOneWidget);
      // Nothing entered the order on its own: the sheet is a review, not a
      // sale, and the stock-ceiling add stays behind its own button.
      expect(staged.order.isEmpty, isTrue);

      // The gate restarts after a commit: a couple of frames cannot re-commit
      // the sheet over the user's hand while they read it.
      await deliverFrames(tester, camera, 2);
      await tester.pumpAndSettle();
      expect(find.text('Line 1: "Bioflu Tablet"'), findsOneWidget);
    });

    testWidgets('an unsteady read never opens it', (tester) async {
      final camera = FakePrescriptionCamera(supportsLive: true);
      final recognizer = FakePrescriptionRecognizer(
        supportsFrameRecognition: true,
        frameReadings: readingsOf('Bioflu Tablet'),
      );
      await pumpLiveScan(tester, camera: camera, recognizer: recognizer);

      // Two agreeable, then a change, then agreement again: no three-in-a-row
      // anywhere, so the sheet stays shut while the camera keeps streaming.
      await deliverFrames(tester, camera, 2);
      await tester.pumpAndSettle();
      recognizer.reframe(readingsOf('Kremil-S Tablet'));
      await deliverFrames(tester, camera, 1);
      await tester.pumpAndSettle();
      recognizer.reframe(readingsOf('Bioflu Tablet'));
      await deliverFrames(tester, camera, 1);
      await tester.pumpAndSettle();

      expect(find.textContaining('Scan result ·'), findsNothing);
      expect(camera.frameSink, isNotNull);
    });

    testWidgets('Done hands the screen back to the live feed', (tester) async {
      final camera = FakePrescriptionCamera(supportsLive: true);
      final recognizer = FakePrescriptionRecognizer(
        supportsFrameRecognition: true,
        frameReadings: readingsOf('Bioflu Tablet'),
      );
      await pumpLiveScan(tester, camera: camera, recognizer: recognizer);

      await deliverFrames(tester, camera, 3);
      await tester.pumpAndSettle();
      expect(find.textContaining('Scan result ·'), findsOneWidget);

      await tester.tap(find.byKey(const Key('commitSheetClose')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Scan result ·'), findsNothing);
      expect(find.text('Line 1: "Bioflu Tablet"'), findsNothing);
    });

    testWidgets('a deliberate scan takes the room an auto-commit held', (
      tester,
    ) async {
      final camera = FakePrescriptionCamera(
        supportsLive: true,
        pictureBytes: Uint8List(64),
      );
      final recognizer = FakePrescriptionRecognizer(
        supportsFrameRecognition: true,
        frameReadings: readingsOf('Bioflu Tablet'),
      );
      await pumpLiveScan(tester, camera: camera, recognizer: recognizer);

      await deliverFrames(tester, camera, 3);
      await tester.pumpAndSettle();

      // The sheet covers the deliberate controls while it is up — that is the
      // point of it: the committed reading is being reviewed, and a second
      // full-width button hiding behind the sheet would be a second moment.
      // Closing it hands the room back, and the deliberate read takes over.
      // Both recognized paths are reframed: the deliberate one reads through
      // `recognize`, the streamed one through `recognizeFrame`, and the test
      // wants whichever answers to now name a different medicine.
      recognizer.readings = readingsOf('Kremil-S Tablet');
      recognizer.reframe(readingsOf('Kremil-S Tablet'));
      await tester.tap(find.byKey(const Key('commitSheetClose')));
      await tester.pumpAndSettle();
      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      expect(find.text('Line 1: "Kremil-S Tablet"'), findsOneWidget);
      expect(find.textContaining('Scan result ·'), findsOneWidget);
    });
  });
}

/// A one-line catalogue whose only product needs a prescription.
///
/// The static list records no Rx line, so the badge needs a catalogue of its
/// own rather than an assertion waiting on data that is not there yet.
class _RxCatalogue implements MedicineRepository {
  const _RxCatalogue();

  static final List<MedicineModel> _items = [
    const MedicineModel(
      productId: '19',
      name: 'Bioflu Tablet',
      priceCentavos: 800,
      stock: 20,
      requiresRx: true,
    ),
  ];

  @override
  List<MedicineModel> all() => _items;

  @override
  List<MedicineModel> search(String query) =>
      query.trim().isEmpty ? all() : _items.where((m) => m.matches(query)).toList();
}

/// One dummy preview frame. The fake recognizer ignores the pixels, so only
/// the shape matters — a valid prescription frame with known geometry.
PrescriptionFrame aFrame() => PrescriptionFrame(
  bytes: Uint8List(8),
  width: 8,
  height: 8,
  bytesPerRow: 8,
  rotationDegrees: 90,
);

/// Stage 2: the committed sheet. The fakes stream frames by hand, letting the
/// tests control exactly how many agreeable reads the gate sees — timing that
/// a real camera would deliver by itself.
///
/// Same shape as [pumpScan], with the fakes built to stream: a live-capable
/// camera and a frame-capable recognizer. The catalogue stays injected so the
/// matched suggestions are exactly [StaticMedicineRepository.seen] above.
Future<({FakePrescriptionCamera camera, OrderProvider order})> pumpLiveScan(
  WidgetTester tester, {
  required FakePrescriptionCamera camera,
  required FakePrescriptionRecognizer recognizer,
  MedicineRepository? repository,
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
          repository: repository ?? const StaticMedicineRepository(),
          camera: camera,
          recognizer: recognizer,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (camera: camera, order: order);
}

/// Pushes [count] agreeable frames through the fake's sink, one `pump` each so
/// the single-flight queue drains between reads — the sequencing the real
/// camera wrapper's throttle gives for free.
Future<void> deliverFrames(
  WidgetTester tester,
  FakePrescriptionCamera camera,
  int count,
) async {
  for (var i = 0; i < count; i++) {
    camera.frameSink!(aFrame());
    await tester.pump(const Duration(milliseconds: 30));
  }
}

