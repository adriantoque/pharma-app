import 'dart:async';

import 'package:pharmaguide/features/scan/domain/prescription_recognizer.dart';
import 'package:pharmaguide/features/scan/presentation/screens/scan_screen.dart';

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

  /// Recordings of what [recognize] was called with, in call order.
  final List<List<InkLine>> recognizeCalls = [];

  int recognizeCallsCount = 0;

  /// When set, the next [recognize] throws this instead of returning [readings].
  Object? recognizeError;

  /// When true, [recognize] never completes until [completeRecognize] runs.
  bool blockRecognize = false;

  Completer<void>? _recognizeGate;

  @override
  Future<List<RecognizedLine>> recognize(Uint8List imageBytes) async {
    recognizeCallsCount++;
    recognizeCalls.add(imageBytes);
    if (recognizeError != null) throw recognizeError!;
    if (blockRecognize) {
      _recognizeGate = Completer<void>();
      await _recognizeGate!.future;
    }
    return readings;
  }

  @override
  Future<bool> isModelReady() async => true;

  @override
  Future<void> ensureModel() async {}

  @override
  Future<void> dispose() async {}
}

/// A single-reading line, which is all most tests need.
RecognizedLine reading(String text, {List<String>? candidates}) =>
    RecognizedLine(candidates != null ? candidates : [text]);

/// The lines a handwritten list of medicines would come back as.
List<RecognizedLine> readingsOf(String first, [String? second, String? third]) => [
  reading(first),
  if (second != null) reading(second),
  if (third != null) reading(third),
];

void completeRecognize() {}