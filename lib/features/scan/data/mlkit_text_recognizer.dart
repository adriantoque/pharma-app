import 'dart:io';

import 'package:flutter/foundation.dart'
    show Uint8List, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/prescription_recognizer.dart';

/// The real recognizer: ML Kit's on-device text recognition over a platform
/// channel.
///
/// This is the only file that imports the plugin, so the rest of the Scan tab
/// works in a widget test against [PrescriptionRecognizer].
///
/// There is no model gate here: ML Kit fetches the Latin model through Google
/// Play Services on first use. A first scan can therefore take a moment, and an
/// install with no connection has to trip the error path instead.
class MlKitTextRecognizer extends PrescriptionRecognizer {
  MlKitTextRecognizer({this.script = defaultScript});

  /// The script recognised by default. Pharmacists in the Philippines write
  /// and print in a Latin script, which is also the smallest and fastest model.
  static const TextRecognitionScript defaultScript =
      TextRecognitionScript.latin;

  /// Frames are readable everywhere the still photos are: both go through the
  /// same on-device model, only their bytes' shape differs.
  @override
  bool get supportsFrames => isSupported;

  final TextRecognitionScript script;

  /// Created on first use and then held for the life of the tab. Each instance
  /// carries a native id, so building one per recognition would leak them.
  TextRecognizer? _recognizer;

  bool _disposed = false;

  @override
  bool get isSupported => !kIsWeb;

  @override
  Future<List<RecognizedLine>> recognize(Uint8List imageBytes) async {
    _checkUsable();
    if (imageBytes.isEmpty) return const [];

    final recognizer = _recognizer ??= TextRecognizer(script: script);
    final tempDir = await Directory.systemTemp.createTemp('pharmaguide_scan');
    final file = File('${tempDir.path}/prescription.jpg');
    try {
      await file.writeAsBytes(imageBytes, flush: true);

      final RecognizedText recognized;
      try {
        recognized = await recognizer.processImage(
          InputImage.fromFilePath(file.path),
        );
      } on MissingPluginException {
        throw PrescriptionRecognitionException(
          'Text recognition is not available on this device.',
          isUnsupportedPlatform: true,
        );
      } on PlatformException catch (error) {
        throw PrescriptionRecognitionException(
          'The prescription could not be read. The text model is fetched from '
          'Google on first use, so a phone that has never run it needs a '
          'connection. (${error.code})',
          isOffline: true,
        );
      }

      return _linesOf(recognized);
    } finally {
      // The input goes through a file because `InputImage.fromFilePath` accepts
      // any encoded picture (JPEG, PNG) without the caller naming its format.
      try {
        await file.delete();
        await tempDir.delete();
      } on FileSystemException {
        // The native side may still hold the file; the OS cache will reclaim it.
      }
    }
  }

  /// Reads a preview frame straight from its pixels — no file round-trip.
  ///
  /// Streaming hands over whichever layout the platform's camera produces, and
  /// it happens to be the two layouts ML Kit eats natively: NV21 on Android,
  /// BGRA on iOS. Nothing is converted here, which is precisely why a frame
  /// can be read `supportsFrames`-speed without heating the phone.
  @override
  Future<List<RecognizedLine>> recognizeFrame(PrescriptionFrame frame) async {
    _checkUsable();
    if (frame.bytes.isEmpty) return const [];

    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final metadata = InputImageMetadata(
      size: Size(frame.width.toDouble(), frame.height.toDouble()),
      rotation: _rotationOf(frame.rotationDegrees),
      format: isIos ? InputImageFormat.bgra8888 : InputImageFormat.nv21,
      // Not used by Android, which reads the packed NV21 layout at row = width.
      bytesPerRow: frame.bytesPerRow,
    );

    final recognizer = _recognizer ??= TextRecognizer(script: script);
    final RecognizedText recognized;
    try {
      recognized = await recognizer.processImage(
        InputImage.fromBytes(bytes: frame.bytes, metadata: metadata),
      );
    } on MissingPluginException {
      throw PrescriptionRecognitionException(
        'Text recognition is not available on this device.',
        isUnsupportedPlatform: true,
      );
    } on PlatformException catch (error) {
      throw PrescriptionRecognitionException(
        'The prescription could not be read. The text model is fetched from '
        'Google on first use, so a phone that has never run it needs a '
        'connection. (${error.code})',
        isOffline: true,
      );
    }

    return _linesOf(recognized);
  }

  /// Every non-empty printed line, in the order the image carries them.
  static List<RecognizedLine> _linesOf(RecognizedText recognized) {
    return [
      for (final block in recognized.blocks)
        for (final line in block.lines)
          if (line.text.trim().isNotEmpty) RecognizedLine(line.text.trim()),
    ];
  }

  static InputImageRotation _rotationOf(int degrees) {
    switch (degrees) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final recognizer = _recognizer;
    _recognizer = null;
    if (recognizer == null) return;

    try {
      await recognizer.close();
    } on MissingPluginException {
      // Nothing native was ever built, so there is nothing to release.
    } on PlatformException {
      // Same: the recognizer is already gone on the native side.
    }
  }

  void _checkUsable() {
    if (_disposed) {
      throw StateError('This recognizer has already been disposed.');
    }
    if (!isSupported) {
      throw PrescriptionRecognitionException(
        'Text recognition is not available on this platform.',
        isUnsupportedPlatform: true,
      );
    }
  }
}
