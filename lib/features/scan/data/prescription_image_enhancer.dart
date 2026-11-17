import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The light text enhancement a deliberate capture gets before ML Kit reads it.
///
/// The camera hands over whatever the sensor saw: a JPEG that may carry an
/// EXIF rotation, flat contrast over grey paper, and soft edges where the
/// print meets the page. Those are exactly the things a photograph is lenient
/// about and OCR is not, so the capture is straightened, pushed a little
/// towards ink-on-paper contrast, and given one unsharp pass to firm the
/// letter edges up.
///
/// "Light" on purpose: ML Kit reads ordinary photos well, and every filter
/// here is a chance to erase a stroke as well as sharpen one. Any failure at
/// any step returns the original bytes \u2014 an unenhanced photo is a downgrade,
/// never a broken scan.
abstract final class PrescriptionImageEnhancer {
  /// How much contrast is pushed in. The `image` package reads 100 as no
  /// change, so 120 is a gentle twenty-percent step \u2014 enough to separate
  /// print from grey paper, not enough to clip a faint carbon copy.
  static const int _contrastBoost = 120;

  /// The unsharp mask's blend. Half strength keeps halos off thin strokes;
  /// full strength is what turns a misread "6" into a "5" the other way.
  static const double _sharpenAmount = 0.5;

  /// The re-encode quality. The photo is OCR fuel, so the point of this encode
  /// is to keep what the filters made rather than to save bytes \u2014 compression
  /// artefacts around letters are precisely the noise the filters removed.
  static const int _jpegQuality = 95;

  /// Returns [bytes] enhanced for text recognition, or [bytes] itself when
  /// anything about the pipeline does not apply.
  ///
  /// The enhancement never throws: an unreadable format, a truncated file or
  /// an OOM on a huge image all fall back to the untouched capture, which the
  /// recognizer reads exactly as it always has.
  static Uint8List enhance(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      // The EXIF rotation is baked into the pixels so the recognizer reads an
      // upright page from bytes that carry no orientation tag of their own.
      final upright = img.bakeOrientation(decoded);

      final contrasted = img.contrast(upright, contrast: _contrastBoost);
      final sharpened = img.convolution(
        contrasted,
        filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
        amount: _sharpenAmount,
      );

      return img.encodeJpg(sharpened, quality: _jpegQuality);
    } catch (_) {
      return bytes;
    }
  }
}
