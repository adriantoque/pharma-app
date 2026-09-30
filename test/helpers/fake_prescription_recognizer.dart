import 'dart:async';

import 'package:pharmaguide/features/scan/domain/ink_stroke.dart';
import 'package:pharmaguide/features/scan/domain/prescription_recognizer.dart';

/// Controllable fake used by the scan widget tests, standing in for ML Kit's
/// platform recognizer so the tests never depend on a downloaded model.
class FakePrescriptionRecognizer implements PrescriptionRecognizer {
  FakePrescriptionRecognizer({
    this.isSupported = true,
    this.modelReady = true,
    this.recognizeError,
    this.ensureModelError,
    this.blockRecognize = false,
    this.blockEnsureModel = false,
    List<RecognizedLine>? readings,
  }) : readings = readings ?? const [];

  /// Stands in for the real capability check; false simulates the web.
  @override
  bool isSupported;

  /// Stands in for whether the ~20 MB model is on the device.
  bool modelReady;

  /// Lines handed back by [recognize].
  List<RecognizedLine> readings;

  /// The lines [recognize] was asked to read, in call order.
  final List<List<InkLine>> recognizeCalls = [];

  int ensureModelCalls = 0;
  int disposeCalls = 0;
  bool closed = false;

  /// When set, the next [recognize] throws this instead of returning [readings].
  Object? recognizeError;

  /// When set, the next [ensureModel] throws this instead of succeeding.
  Object? ensureModelError;

  /// When true, [recognize] never completes until [completeRecognize] runs.
  bool blockRecognize = false;
  Completer<void>? _recognizeGate;

  /// When true, [ensureModel] never completes until [completeDownload] runs.
  bool blockEnsureModel = false;
  Completer<void>? _ensureModelGate;

  @override
  Future<List<RecognizedLine>> recognize(List<InkLine> lines) async {
    recognizeCalls.add(lines);
    if (recognizeError != null) throw recognizeError!;
    if (blockRecognize) {
      _recognizeGate = Completer<void>();
      await _recognizeGate!.future;
    }
    return readings;
  }

  @override
  Future<bool> isModelReady() async => modelReady;

  @override
  Future<void> ensureModel() async {
    ensureModelCalls++;
    if (ensureModelError != null) throw ensureModelError!;
    if (blockEnsureModel) {
      _ensureModelGate = Completer<void>();
      await _ensureModelGate!.future;
    }
    modelReady = true;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    closed = true;
  }

  void completeRecognize() {
    _recognizeGate?.complete();
    _recognizeGate = null;
  }

  void completeDownload() {
    _ensureModelGate?.complete();
    _ensureModelGate = null;
  }
}

/// A single-reading line, which is all most tests need.
RecognizedLine reading(String text, {List<String>? candidates}) =>
    RecognizedLine(candidates ?? [text]);

/// The lines a handwritten list of medicines would come back as.
List<RecognizedLine> readingsOf(String first, [String? second, String? third]) => [
  reading(first),
  if (second != null) reading(second),
  if (third != null) reading(third),
];
