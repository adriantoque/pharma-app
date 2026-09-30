import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/scan/data/mlkit_prescription_recognizer.dart';
import 'package:pharmaguide/features/scan/domain/ink_stroke.dart';
import 'package:pharmaguide/features/scan/domain/prescription_recognizer.dart';

/// The real adapter is the one piece that talks to the plugin, so it is tested
/// against a mocked platform channel rather than left to the device alone. A
/// shape change on either side of that channel is exactly the kind of breakage
/// that leaves the app compiling and returning nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('google_mlkit_digital_ink_recognizer');

  /// Every call made to the plugin, in order.
  late List<MethodCall> calls;

  /// What the recognizer answers with, keyed by how many strokes it has been
  /// sent, so lines of different lengths can be given different readings.
  late Map<int, List<Map<String, Object>>> answers;

  /// What the recognizer answers with in call order, which is the only way to
  /// tell lines apart when they are all the same length.
  late List<List<Map<String, Object>>> answersInOrder;

  late int recognizeCalls;

  late void Function(MethodCall call) onCall;

  /// A row of handwriting: a stroke of [height] starting at [y].
  InkLine lineAt(double y, {double height = 20}) => InkLine([
    InkStroke([
      for (var i = 0; i <= 4; i++)
        InkPoint(x: i * 5.0, y: y + height * i / 4, t: 1000 + i * 10),
    ]),
  ]);

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          onCall(call);

          if (call.method == 'vision#startDigitalInkRecognizer') {
            final ink = (call.arguments as Map)['ink'] as Map;
            final strokes = (ink['strokes'] as List).length;
            final index = recognizeCalls++;

            if (index < answersInOrder.length) {
              return answersInOrder[index];
            }
            return answers[strokes] ??
                [
                  {'text': 'answer', 'score': 1.0},
                ];
          }

          // A check is answered with a flag; a download or a delete is
          // acknowledged by name.
          final task = (call.arguments as Map)['task'];
          return task == 'check' ? true : 'success';
        });
  }

  setUp(() {
    calls = [];
    answers = {};
    answersInOrder = [];
    recognizeCalls = 0;
    onCall = (_) {};
    install();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// The arguments of the nth recognition call.
  Map recognitionAt(int index) {
    final recognize = calls
        .where((c) => c.method == 'vision#startDigitalInkRecognizer')
        .toList();
    return recognize[index].arguments as Map;
  }

  /// A channel argument comes back with untyped keys, so the points are read
  /// through whatever the platform channel hands over.
  List<Map<Object?, Object?>> pointsOf(Map arguments) {
    final ink = arguments['ink'] as Map;
    final strokes = ink['strokes'] as List;
    return [
      for (final point in (strokes.first as Map)['points'] as List)
        point as Map<Object?, Object?>,
    ];
  }

  group('ink', () {
    test('sends one stroke with its points', () async {
      await MlKitPrescriptionRecognizer().recognize([lineAt(0)]);

      final points = pointsOf(recognitionAt(0));
      expect(points, hasLength(5));
      expect(points.first, containsPair('x', 0.0));
      expect(points.last, containsPair('x', 20.0));
    });

    test('rebases each line to start at zero', () async {
      // The second line is written seconds after the first, but the recognizer
      // is handed one gesture at a time and a wall-clock gap would read as a
      // very slow, deliberate stroke.
      final later = InkLine([
        InkStroke([
          const InkPoint(x: 0, y: 0, t: 9000),
          const InkPoint(x: 10, y: 10, t: 9500),
        ]),
      ]);

      await MlKitPrescriptionRecognizer().recognize([lineAt(0), later]);

      final points = pointsOf(recognitionAt(1));
      expect(points.first['t'], 0);
      expect(points.last['t'], 500);
    });

    test('never sends a negative timestamp', () async {
      final line = InkLine([
        InkStroke([
          const InkPoint(x: 0, y: 0, t: 100),
          const InkPoint(x: 5, y: 5, t: 50),
        ]),
      ]);

      await MlKitPrescriptionRecognizer().recognize([line]);

      for (final point in pointsOf(recognitionAt(0))) {
        expect(point['t'], greaterThanOrEqualTo(0));
      }
    });

    test('asks for the model it was built with', () async {
      await MlKitPrescriptionRecognizer().recognize([lineAt(0)]);

      expect(recognitionAt(0)['model'], 'en-US');
    });
  });

  group('one call per line', () {
    test('sends each line separately', () async {
      await MlKitPrescriptionRecognizer().recognize([
        lineAt(0),
        lineAt(40),
        lineAt(80),
      ]);

      expect(
        calls.where((c) => c.method == 'vision#startDigitalInkRecognizer'),
        hasLength(3),
      );
    });

    test('reuses one native recognizer across lines', () async {
      final recognizer = MlKitPrescriptionRecognizer();

      await recognizer.recognize([lineAt(0)]);
      await recognizer.recognize([lineAt(40)]);

      // Every call carries the same instance id, so the native side builds one
      // recognizer rather than one per line.
      final ids = calls
          .where((c) => c.method == 'vision#startDigitalInkRecognizer')
          .map((c) => (c.arguments as Map)['id'])
          .toSet();
      expect(ids, hasLength(1));
    });

    test('sends nothing at all for no lines', () async {
      final readings = await MlKitPrescriptionRecognizer().recognize([]);

      expect(readings, isEmpty);
      expect(calls, isEmpty);
    });
  });

  group('writing area', () {
    test('describes the line it was sent', () async {
      await MlKitPrescriptionRecognizer().recognize([lineAt(10, height: 20)]);

      final area =
          (recognitionAt(0)['context'] as Map)['writingArea'] as Map;
      expect(area['width'], 20.0);
      expect(area['height'], 20.0);
    });

    test('never describes a line as smaller than a character', () async {
      // A single tap has a box of nothing, and a writing area that small makes
      // the model treat every stroke as a full glyph.
      final dot = InkLine([
        InkStroke([const InkPoint(x: 5, y: 5, t: 0)]),
      ]);

      await MlKitPrescriptionRecognizer().recognize([dot]);

      final area =
          (recognitionAt(0)['context'] as Map)['writingArea'] as Map;
      expect(area['width'], greaterThanOrEqualTo(16));
      expect(area['height'], greaterThanOrEqualTo(16));
    });
  });

  group('pre-context', () {
    test('carries the previous line forward', () async {
      answersInOrder = [
        [
          {'text': 'Amox 500mg', 'score': 1.0},
        ],
      ];

      await MlKitPrescriptionRecognizer().recognize([lineAt(0), lineAt(40)]);

      // Trailing space trimmed: the pre-context is a prefix of the next line's
      // surroundings, not a finished sentence.
      expect(
        (recognitionAt(1)['context'] as Map)['preContext'],
        'Amox 500mg',
      );
    });

    test('is empty on the first line', () async {
      await MlKitPrescriptionRecognizer().recognize([lineAt(0)]);

      final context = recognitionAt(0)['context'] as Map;
      // The plugin drops a context with nothing in it, so the first line is
      // sent without one.
      expect(context['preContext'], '');
    });

    test('keeps only the last twenty characters', () async {
      // ML Kit truncates pre-context itself, but sending more than it wants
      // means the model is told about words that are not adjacent to the line
      // being read.
      answersInOrder = [
        [
          {'text': 'aaaaaaaaaa bbbbbbbbbb cccccccccc dddddddddd', 'score': 1.0},
        ],
      ];

      await MlKitPrescriptionRecognizer().recognize([lineAt(0), lineAt(40)]);

      final preContext =
          (recognitionAt(1)['context'] as Map)['preContext'] as String;
      expect(preContext, hasLength(20));
    });

    test('skips a line that read as nothing', () async {
      const biogasic = [
        {'text': 'Biogesic', 'score': 1.0},
      ];
      answersInOrder = [
        const [],
        biogasic,
        biogasic,
      ];

      await MlKitPrescriptionRecognizer().recognize([
        lineAt(0),
        lineAt(40),
        lineAt(80),
      ]);

      // Line one gave nothing, so line two starts with no pre-context, and line
      // three carries line two rather than the blank line one.
      expect((recognitionAt(1)['context'] as Map)['preContext'], '');
      expect(
        (recognitionAt(2)['context'] as Map)['preContext'],
        'Biogesic',
      );
    });
  });

  group('candidates', () {
    test('keeps every reading the model offered', () async {
      answers = {
        1: [
          {'text': 'Amox 500ng', 'score': 0.1},
          {'text': 'Amox 500mg', 'score': 0.2},
        ],
      };

      final readings = await MlKitPrescriptionRecognizer().recognize([
        lineAt(0),
      ]);

      // The matcher picks between these, so dropping the second one here would
      // throw away the only chance of getting the reading right.
      expect(readings.single.candidates, ['Amox 500ng', 'Amox 500mg']);
      expect(readings.single.best, 'Amox 500ng');
    });

    test('drops a blank reading', () async {
      answers = {
        1: [
          {'text': '   ', 'score': 0.1},
          {'text': 'Amox', 'score': 0.2},
        ],
      };

      final readings = await MlKitPrescriptionRecognizer().recognize([
        lineAt(0),
      ]);

      expect(readings.single.candidates, ['Amox']);
    });

    test('trims what it keeps', () async {
      answers = {
        1: [
          {'text': '  Amox 500mg \n', 'score': 1.0},
        ],
      };

      final readings = await MlKitPrescriptionRecognizer().recognize([
        lineAt(0),
      ]);

      expect(readings.single.candidates, ['Amox 500mg']);
    });

    test('returns a line even when the model found nothing', () async {
      answers = {1: const []};

      final readings = await MlKitPrescriptionRecognizer().recognize([
        lineAt(0),
      ]);

      expect(readings, hasLength(1));
      expect(readings.single.candidates, isEmpty);
      expect(readings.single.best, isNull);
    });
  });

  group('the model', () {
    test('checks whether it is downloaded', () async {
      onCall = (_) {};

      expect(await MlKitPrescriptionRecognizer().isModelReady(), isTrue);

      final call = calls.single;
      expect(call.method, 'vision#manageInkModels');
      expect((call.arguments as Map)['task'], 'check');
      expect((call.arguments as Map)['model'], 'en-US');
    });

    test('downloads over mobile data too', () async {
      // ML Kit defaults to refusing a mobile download, which would strand
      // anyone on a metered or unstable connection with a 20 MB spinner.
      await MlKitPrescriptionRecognizer().ensureModel();

      final call = calls.single;
      expect((call.arguments as Map)['task'], 'download');
      expect((call.arguments as Map)['wifi'], isFalse);
    });
  });

  group('failures', () {
    test('turns a failed download into something the screen can show', () async {
      onCall = (call) {
        throw PlatformException(code: 'no-network');
      };

      await expectLater(
        MlKitPrescriptionRecognizer().ensureModel(),
        throwsA(
          isA<PrescriptionRecognitionException>()
              .having((e) => e.isOffline, 'isOffline', isTrue)
              .having((e) => e.message, 'message', contains('20 MB')),
        ),
      );
    });

    test('treats a read failure as a missing model', () async {
      onCall = (call) {
        if (call.method == 'vision#startDigitalInkRecognizer') {
          throw PlatformException(code: 'model-not-ready');
        }
      };

      await expectLater(
        MlKitPrescriptionRecognizer().recognize([lineAt(0)]),
        throwsA(
          isA<PrescriptionRecognitionException>()
              .having((e) => e.isModelMissing, 'isModelMissing', isTrue),
        ),
      );
    });

    test('reports a missing plugin as an unsupported platform', () async {
      onCall = (call) {
        throw MissingPluginException();
      };

      await expectLater(
        MlKitPrescriptionRecognizer().ensureModel(),
        throwsA(
          isA<PrescriptionRecognitionException>()
              .having(
                (e) => e.isUnsupportedPlatform,
                'isUnsupportedPlatform',
                isTrue,
              ),
        ),
      );
    });

    test('reports a model that cannot be checked as not downloaded', () async {
      onCall = (call) {
        throw PlatformException(code: 'unavailable');
      };

      // The screen offers a download on the strength of this, and downloading a
      // model that is already there is harmless.
      expect(await MlKitPrescriptionRecognizer().isModelReady(), isFalse);
    });

    test('refuses to work after being disposed', () async {
      final recognizer = MlKitPrescriptionRecognizer();
      await recognizer.recognize([lineAt(0)]);
      await recognizer.dispose();

      await expectLater(
        recognizer.recognize([lineAt(0)]),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('disposal', () {
    test('closes the native recognizer', () async {
      final recognizer = MlKitPrescriptionRecognizer();
      await recognizer.recognize([lineAt(0)]);

      await recognizer.dispose();

      expect(
        calls.where((c) => c.method == 'vision#closeDigitalInkRecognizer'),
        hasLength(1),
      );
    });

    test('can be called twice', () async {
      final recognizer = MlKitPrescriptionRecognizer();
      await recognizer.recognize([lineAt(0)]);

      await recognizer.dispose();
      await recognizer.dispose();

      expect(
        calls.where((c) => c.method == 'vision#closeDigitalInkRecognizer'),
        hasLength(1),
      );
    });

    test('does nothing when there was never a recognizer', () async {
      await MlKitPrescriptionRecognizer().dispose();

      expect(calls, isEmpty);
    });
  });
}
