import 'dart:async';
import 'dart:typed_data';

import 'package:pharmaguide/features/scan/domain/prescription_recognizer.dart';

/// Controllable fake used by the scan widget tests, standing in for ML Kit's
/// platform recognizer so the tests never depend on a downloaded model.
class FakePrescriptionRecognizer implements PrescriptionRecognizer {
  FakePrescriptionRecognizer({
    this.isSupported = true,
    this.recognizeError,
    this.blockRecognize = false,
    List<RecognizedLine>? readings,
  }) : readings = readings ?? const [];

  /// Stands in for the real capability check; false simulates the web.
  @override
  bool isSupported;

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
