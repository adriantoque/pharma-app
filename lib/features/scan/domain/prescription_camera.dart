import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Widget;

import 'prescription_recognizer.dart';

/// The camera the Scan tab captures a prescription with.
///
/// The interface exists so the Scan tab can be driven in a widget test: the
/// real implementation wraps the `camera` and `image_picker` plugins, neither
/// of which exists under the test binding, and a fake that returns canned
/// results is cheaper and more precise than mocking their channels.
abstract class PrescriptionCamera {
  /// Whether this platform has a camera and a way to pick a photo at all.
  ///
  /// Web can show a camera preview but has no ML Kit behind it, so the whole
  /// Scan feature reports it as unsupported rather than starting previews that
  /// can never be read.
  bool get isSupported;

  /// Opens the camera and starts the live preview.
  ///
  /// Throws [PrescriptionRecognitionException] with [isPermissionDenied] when
  /// the user refused, [isUnsupportedPlatform] on a platform with no native
  /// camera. Safe to call more than once.
  Future<void> initialize();

  /// Whether the preview is running, i.e. a frame can be captured.
  bool get isReady;

  /// The live preview to show the user. Non-null only once [initialize] has
  /// succeeded; a fake camera returns whatever stands in for it under test.
  Widget? get preview;

  /// Captures the current frame. Only valid while [isReady].
  ///
  /// Returns the picture as encoded image bytes. Throws
  /// [PrescriptionRecognitionException] when the capture failed.
  Future<Uint8List> takePicture();

  /// Lets the user pick a photo of a prescription from their library.
  ///
  /// Works even when the camera never started — a denied permission or a
  /// missing back camera must not take the fallback away. Returns null when
  /// the user changed their mind. Throws [PrescriptionRecognitionException]
  /// when the pick failed.
  Future<Uint8List?> pickFromGallery();

  /// Releases the camera. Safe to call more than once.
  Future<void> dispose();
}
