import 'dart:async';
import 'dart:typed_data';

import 'package:pharmaguide/features/scan/domain/prescription_recognizer.dart';

/// Controllable fake used by the scan widget tests, standing in for ML Kit's
/// platform recognizer so the tests never depend on a downloaded model.
class FakePrescriptionRecognizer extends PrescriptionRecognizer {
  FakePrescriptionRecognizer({
    this.isSupported = true,
    this.recognizeError,
    this.blockRecognize = false,
    List<RecognizedLine>? readings,
    this.supportsFrameRecognition = false,
    this.frameError,
    List<RecognizedLine>? frameReadings,
  }) : readings = readings ?? const [],
       frameReadings = frameReadings ?? readings ?? const [];

  /// Stands in for the real capability check; false simulates the web.
  @override
  bool isSupported;

  /// Whether the fake can read a preview frame. Defaults to false — the same
  /// verdict the shared default gives — so only tests that stage the live
  /// flow turn it on.
  @override
  bool get supportsFrames => supportsFrameRecognition;
  bool supportsFrameRecognition;

  /// When set, [recognizeFrame] throws this instead of reading.
  Object? frameError;

  /// Lines handed back by [recognizeFrame]. Defaults to [readings], so a
  /// streaming test and a deliberate test can share one expectation set.
  List<RecognizedLine> frameReadings;

  /// How many frames [recognizeFrame] was handed.
  int frameCalls = 0;

  /// Lines handed back by [recognize].
  List<RecognizedLine> readings;

  /// The bytes [recognize] was called with, in call order.
  final List<Uint8List> recognizeCalls = [];

  /// Whether [dispose] has run.
  ///
  /// The screen releases the recognizer it was handed, so a test can assert
  /// nothing built here outlives the tab.
  bool disposed = false;

  /// When set, [recognize] throws this instead of returning [readings].
  Object? recognizeError;

  /// When true, [recognize] never completes until [completeRecognize] runs.
  bool blockRecognize = false;

  Completer<void>? _recognizeGate;

  @override
  Future<List<RecognizedLine>> recognize(Uint8List imageBytes) async {
    recognizeCalls.add(imageBytes);
    if (recognizeError != null) throw recognizeError!;
    if (blockRecognize) {
      _recognizeGate = Completer<void>();
      await _recognizeGate!.future;
    }
    return readings;
  }

  /// Releases the gate [blockRecognize] opened.
  ///
  /// Safe to call when nothing is blocking, so a test does not have to track
  /// whether it reached the await yet.
  void completeRecognize() {
    final gate = _recognizeGate;
    _recognizeGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  /// Changes the readings every streamed frame will produce: the mechanism a
  /// stability test uses to break the gate's run of agreement.
  void reframe(List<RecognizedLine> newReadings) {
    frameReadings = newReadings;
  }

  /// The frame path of [recognize]: same canned answer, countable, and able to
  /// fail through [frameError] the way the deliberate path does.
  @override
  Future<List<RecognizedLine>> recognizeFrame(PrescriptionFrame frame) async {
    frameCalls++;
    if (frameError != null) throw frameError!;
    return frameReadings;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

/// A single-reading line, which is all most tests need.
RecognizedLine reading(String text) => RecognizedLine(text);

/// The lines a printed list of medicines comes back as.
List<RecognizedLine> readingsOf(
  String first, [
  String? second,
  String? third,
]) => [
  reading(first),
  if (second != null) reading(second),
  if (third != null) reading(third),
];
