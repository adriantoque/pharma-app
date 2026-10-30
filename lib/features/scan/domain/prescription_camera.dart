import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Widget;

import 'prescription_recognizer.dart';

/// The camera the Scan tab captures a prescription with.
///
/// Beyond capture and preview, the interface carries the two things the live
/// scanner needs from the device: a steady torch for dim counters, and the
/// preview itself as a stream of frames the recognizer can read. Both arrive
/// defaulted rather than abstract — a fake answers false and never has to grow
/// members it does not use, and the tab treats false as a downgrade to the
/// deliberate photo flow instead of an error.
abstract class PrescriptionCamera {
  /// Whether this platform has a camera at all.
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

  /// Whether the preview torch can be toggled at all.
  bool get supportsTorch => false;

  /// Lights the preview with the flash LED on or off.
  ///
  /// Safe to call before [initialize]. Throws
  /// [PrescriptionRecognitionException] when the device refused — a camera
  /// that can fire its flash for a photo but not hold a steady light.
  Future<void> setTorch(bool enabled) async {
    throw PrescriptionRecognitionException('The camera has no torch here.');
  }

  /// Whether the preview can be streamed as readable frames at all.
  bool get supportsLiveFrames => false;

  /// Starts feeding [onFrame] the preview, frame by frame — the raw material
  /// of the live scanner.
  ///
  /// Frames arrive at whatever cadence the device chose; pacing them is up to
  /// the reader, which queues at most one at a time anyway. Deliberate capture
  /// remains valid the whole time: an implementation pauses its own stream
  /// around a [takePicture] and resumes without anything being asked twice.
  /// Throws [PrescriptionRecognitionException] when streaming could not start.
  /// Only valid while [isReady].
  Future<void> startLiveFrames(
    void Function(PrescriptionFrame frame) onFrame,
  ) async {
    throw PrescriptionRecognitionException('Live frames are not supported.');
  }

  /// Stops the frame stream. Safe to call when it was never started.
  Future<void> stopLiveFrames() async {}

  /// Releases the camera. Safe to call more than once.
  Future<void> dispose();
}
