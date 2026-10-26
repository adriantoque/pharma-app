import 'package:flutter/foundation.dart';

/// What the recognizer made of one line of printed text.
///
/// One line in, one reading out. ML Kit's own ranking is not carried through:
/// the matcher scores this text against the catalogue instead, which is what
/// turns a noisy reading such as "Amoxcilln 500" into the right medicine, and a
/// second candidate would only be a reading of the same line anyway.
@immutable
class RecognizedLine {
  const RecognizedLine(this.text);

  /// The text read on this line, already trimmed. Empty when the image held no
  /// recognisable text.
  final String text;
}

/// One raw frame from the camera preview, already in the pixel layout the
/// recognizer on that platform consumes directly.
///
/// The camera wrapper does the platform's work — an Android frame is handed
/// over as NV21, an iOS one as BGRA — so the recognizer has nothing to do but
/// pass the bytes to ML Kit. Frames bypass the file round-trip a photo needs,
/// which is what makes reading them continuously cheap enough to be worth it.
@immutable
class PrescriptionFrame {
  const PrescriptionFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.rotationDegrees,
  });

  /// The frame's pixels: NV21 on Android, BGRA on iOS.
  final Uint8List bytes;

  /// Frame dimensions, in pixels.
  final int width;
  final int height;

  /// The row stride, in bytes. NV21 packs its rows at exactly [width]; a BGRA
  /// buffer can carry row padding the recognizer has to be told about.
  final int bytesPerRow;

  /// How the sensor sits in the device relative to the upright picture, in
  /// degrees. The recognizer reports it to ML Kit so a streamed frame is read
  /// the right way up regardless of how the phone was held.
  final int rotationDegrees;
}

/// Reads a photograph of a prescription, one line at a time.
///
/// The interface exists so the Scan tab can be driven in a widget test. The
/// real implementation is a platform channel, and a fake that returns canned
/// readings is both cheaper and more precise than trying to stub a channel.
///
/// There is no model-download step here on purpose: ML Kit's text recognition
/// downloads its Latin model through Google Play Services on first use, so the
/// recognizer has nothing to gate before [recognize] can be called.
abstract class PrescriptionRecognizer {
  /// Whether this platform has a native recognizer at all.
  ///
  /// Web does not, and that is a downgrade rather than a failure: the manual
  /// search in the tab is plain Dart and still works there. Keeping the question
  /// on the interface is what stops the widget from having to know what a
  /// platform is.
  bool get isSupported;

  /// Whether [recognizeFrame] has a real implementation here.
  ///
  /// The Scan tab downgrades to the deliberate photo flow when it is false
  /// rather than streaming frames the recognizer could never read. A fake
  /// without an override answers false, which is exactly what it should mean:
  /// tests keep driving photos and nothing starts running in the background.
  bool get supportsFrames => false;

  /// Reads one line of text out of a preview frame, straight from its pixels.
  ///
  /// Thrown as-is by the default body rather than being abstract, so the
  /// recognizers that do not stream carry no obligation, and a caller that
  /// overrides [supportsFrames] check still fails recognisably rather than
  /// ever reading silence. Throws [PrescriptionRecognitionException] the way
  /// [recognize] does.
  Future<List<RecognizedLine>> recognizeFrame(PrescriptionFrame frame) async {
    throw PrescriptionRecognitionException(
      'Frame recognition is not supported on this recognizer.',
      isUnsupportedPlatform: true,
    );
  }

  /// Reads every line the picture contains, returning one entry per line in
  /// the order they appear.
  ///
  /// Throws [PrescriptionRecognitionException] when the platform has no
  /// recognizer or the model could not be fetched — a freshly installed app
  /// with no connection is the common case.
  Future<List<RecognizedLine>> recognize(Uint8List imageBytes);

  /// Releases the native recognizer. Safe to call more than once.
  Future<void> dispose();
}

/// A recognizer or camera that could not do the job, in terms the screen can
/// show.
class PrescriptionRecognitionException implements Exception {
  PrescriptionRecognitionException(
    this.message, {
    this.isUnsupportedPlatform = false,
    this.isOffline = false,
    this.isPermissionDenied = false,
  });

  /// What went wrong, phrased for a person rather than a log.
  final String message;

  /// True on a platform with no native recognizer, such as web. The manual
  /// search in the tab still works there, so this is a downgrade and not an
  /// error the user has to do anything about.
  final bool isUnsupportedPlatform;

  /// True when the algorithm's model download failed for want of a connection,
  /// which is worth offering a retry for.
  final bool isOffline;

  /// True when the camera could not start because the permission was refused.
  /// Recognition from a gallery photo and the manual search both still work.
  final bool isPermissionDenied;

  @override
  String toString() => 'PrescriptionRecognitionException: $message';
}
