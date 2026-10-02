import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
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
class MlKitTextRecognizer implements PrescriptionRecognizer {
  MlKitTextRecognizer({this.script = defaultScript});

  /// The script recognised by default. Pharmacists in the Philippines write
  /// and print in a Latin script, which is also the smallest and fastest model.
  static const TextRecognitionScript defaultScript =
      TextRecognitionScript.latin;

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

      return [
        for (final block in recognized.blocks)
          for (final line in block.lines)
            if (line.text.trim().isNotEmpty) RecognizedLine(line.text.trim()),
      ];
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
