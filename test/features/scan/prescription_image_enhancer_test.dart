import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pharmaguide/features/scan/data/prescription_image_enhancer.dart';

/// The enhancement pipeline sits between the camera and ML Kit, so its one job
/// is "make the text easier to read, never fail": these tests pin the pixels it
/// improves and the bytes it leaves alone.
void main() {
  /// A low-contrast page: grey paper (200) with darker print (160), soft
  /// throughout — the photo a phone takes of a receipt under counter light.
  Uint8List softPageJpeg() {
    final page = img.Image(width: 200, height: 100);
    for (final pixel in page) {
      final inText = pixel.y > 40 && pixel.y < 60 && pixel.x > 20 && pixel.x < 180;
      final level = inText ? 160 : 200;
      pixel..r = level..g = level..b = level;
    }
    return img.encodeJpg(page, quality: 90);
  }

  group('PrescriptionImageEnhancer.enhance', () {
    test('returns decodable, changed bytes for a real photo', () {
      final input = softPageJpeg();

      final output = PrescriptionImageEnhancer.enhance(input);

      expect(output, isNot(same(input)));
      final decoded = img.decodeImage(output);
      expect(decoded, isNotNull);
      expect(decoded!.width, 200);
      expect(decoded.height, 100);
    });

    test('increases the contrast the print carries', () {
      double stddevOf(Uint8List bytes) {
        final image = img.decodeImage(bytes)!;
        final values = [
          for (final pixel in image)
            (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b),
        ];
        final mean = values.reduce((a, b) => a + b) / values.length;
        final variance =
            values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
                values.length;
        return sqrt(variance);
      }

      final input = softPageJpeg();
      final output = PrescriptionImageEnhancer.enhance(input);

      // The whole point of the contrast step: the spread between print and
      // paper grows, which is the separation ML Kit reads letters by.
      expect(stddevOf(output), greaterThan(stddevOf(input)));
    });

    test('returns unreadable bytes unchanged rather than throwing', () {
      final garbage = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      final output = PrescriptionImageEnhancer.enhance(garbage);

      expect(identical(garbage, output), isTrue);
    });

    test('returns empty bytes unchanged rather than throwing', () {
      final empty = Uint8List(0);

      final output = PrescriptionImageEnhancer.enhance(empty);

      expect(identical(empty, output), isTrue);
    });

    test('returns truncated-photo bytes unchanged rather than throwing', () {
      final truncated = softPageJpeg().sublist(0, 40);

      final output = PrescriptionImageEnhancer.enhance(truncated);

      // A truncated JPEG may or may not decode to something; either way the
      // pipeline's answer is the original bytes, never an exception.
      expect(
        identical(truncated, output) || img.decodeImage(output) != null,
        isTrue,
      );
    });
  });
}
