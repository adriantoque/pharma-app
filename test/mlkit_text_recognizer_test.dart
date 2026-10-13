import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/scan/data/mlkit_text_recognizer.dart';
import 'package:pharmaguide/features/scan/domain/prescription_recognizer.dart';

/// The plugin talks over this channel, so it can be stood in for without a
/// device. Named here rather than imported, because the plugin keeps it
/// private.
const _pluginChannel = MethodChannel('google_mlkit_text_recognizer');

/// One line as the native side would report it.
///
/// `points` and `rect` are required by the plugin's own parser but nothing in
/// this feature reads them, so the smallest legal shape is used.
Map<String, Object?> _line(String text) => {
  'text': text,
  'rect': {'left': 0, 'top': 0, 'right': 1, 'bottom': 1},
  'recognizedLanguages': ['en'],
  'points': <Object?>[],
  // The parser walks both unconditionally, so they must be present even empty.
  'elements': <Object?>[],
  'symbols': <Object?>[],
};

Map<String, Object?> _block(List<String> lines) => {
  'text': lines.join('\n'),
  'rect': {'left': 0, 'top': 0, 'right': 1, 'bottom': 1},
  'recognizedLanguages': ['en'],
  'points': <Object?>[],
  'lines': [for (final line in lines) _line(line)],
};

/// Covers [MlKitTextRecognizer] against a mocked plugin channel.
///
/// The native recognizer is the only part that needs a device, and it is
/// reached over a [MethodChannel], so everything around it is testable here.
/// What still needs hardware is whether ML Kit reads a real prescription
/// correctly -- see the deferred integration test.
void main() {
  // The mocked plugin channel is reached through the test binary messenger,
  // which only exists once the binding is initialized. Without this, every
  // setUp throws "Binding has not yet been initialized" before a test runs.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every method the recognizer sent to the plugin, in order.
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, (call) async {
      calls.add(call);
      if (call.method == 'vision#startTextRecognizer') {
        return <String, Object?>{
          'text': '',
          'blocks': [
            _block(['Amox 500mg', 'cefalexin']),
          ],
        };
      }
      // `vision#closeTextRecognizer` has no payload worth reading.
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, null);
  });

  group('isSupported', () {
    test('tracks whether this platform has a native recognizer', () {
      expect(MlKitTextRecognizer().isSupported, !kIsWeb);
    });
  });

  group('recognize', () {
    test(
      'returns one trimmed line per non-blank line the photo held',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_pluginChannel, (call) async {
              calls.add(call);
              return <String, Object?>{
                'text': '',
                'blocks': [
                  _block(['  Amox 500mg  ', '   ', 'cefalexin']),
                  _block(['paracetamol']),
                ],
              };
            });

        final lines = await MlKitTextRecognizer().recognize(
          Uint8List.fromList([1, 2, 3]),
        );

        expect(lines.map((line) => line.text), [
          'Amox 500mg',
          'cefalexin',
          'paracetamol',
        ]);
      },
    );

    test(
      'short-circuits on empty bytes without troubling the plugin',
      () async {
        final lines = await MlKitTextRecognizer().recognize(Uint8List(0));

        expect(lines, isEmpty);
        // Nothing was written or recognised, so the channel was never called.
        expect(calls, isEmpty);
      },
    );

    test('reports a missing plugin as an unsupported platform', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pluginChannel, (call) async {
            throw MissingPluginException('no implementation');
          });

      await expectLater(
        MlKitTextRecognizer().recognize(Uint8List.fromList([1])),
        throwsA(
          isA<PrescriptionRecognitionException>()
              .having(
                (e) => e.isUnsupportedPlatform,
                'isUnsupportedPlatform',
                isTrue,
              )
              .having((e) => e.isOffline, 'isOffline', isFalse),
        ),
      );
    });

    test('reports a platform failure as needing a connection', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pluginChannel, (call) async {
            throw PlatformException(code: 'no-model');
          });

      await expectLater(
        MlKitTextRecognizer().recognize(Uint8List.fromList([1])),
        throwsA(
          isA<PrescriptionRecognitionException>()
              .having((e) => e.isOffline, 'isOffline', isTrue)
              .having(
                (e) => e.isUnsupportedPlatform,
                'isUnsupportedPlatform',
                isFalse,
              )
              // The code is carried through so the cause is not lost.
              .having((e) => e.message, 'message', contains('no-model')),
        ),
      );
    });
  });

  group('dispose', () {
    test('stops the recognizer being used again', () async {
      final recognizer = MlKitTextRecognizer();
      await recognizer.dispose();

      expect(
        () => recognizer.recognize(Uint8List.fromList([1])),
        throwsA(isA<StateError>()),
      );
    });

    test('is idempotent, and releases the native side only once', () async {
      final recognizer = MlKitTextRecognizer();
      await recognizer.recognize(Uint8List.fromList([1]));
      calls.clear();

      await recognizer.dispose();
      await recognizer.dispose();

      expect(
        calls.where((c) => c.method == 'vision#closeTextRecognizer'),
        hasLength(1),
      );
    });

    test('does nothing when nothing was ever recognised', () async {
      await MlKitTextRecognizer().dispose();

      expect(
        calls.where((c) => c.method == 'vision#closeTextRecognizer'),
        isEmpty,
      );
    });
  });
}