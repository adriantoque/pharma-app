import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pharmaguide/features/scan/domain/prescription_camera.dart';

/// A fake [PrescriptionCamera] for widget tests.
///
/// The real implementation wraps the `camera` and `image_picker` plugins,
/// neither of which exists under the test binding, so it reaches for a platform
/// channel that is not there. This fake hands back canned bytes instead, and
/// can be told to fail the same way a real device would.
///
/// The preview is a placeholder rather than a camera feed; nothing under test
/// reads pixels from it.
class FakePrescriptionCamera implements PrescriptionCamera {
  FakePrescriptionCamera({
    this.isSupported = true,
    this.initializeError,
    this.takePictureError,
    this.pictureBytes,
    this.galleryBytes,
  });

  /// Stands in for the real capability check; false simulates the web.
  @override
  bool isSupported;

  /// When set, [initialize] throws this instead of opening a preview.
  Object? initializeError;

  /// When set, [takePicture] throws this instead of returning [pictureBytes].
  Object? takePictureError;

  /// What [takePicture] returns. Only has to be non-empty, because the fake
  /// recognizer ignores the bytes entirely.
  final Uint8List? pictureBytes;

  /// What [pickFromGallery] returns. Null means the user backed out of the
  /// picker, which is a path worth covering on its own.
  final Uint8List? galleryBytes;

  /// Whether [dispose] has run, so a test can assert the tab let go.
  bool disposed = false;

  /// How many times [initialize] was actually attempted.
  ///
  /// A retry that never reaches here would leave this at 1, so a test can tell
  /// "the retry worked" from "the retry silently did nothing".
  int initializeCalls = 0;

  bool _ready = false;
  bool _initializing = false;

  @override
  bool get isReady => _ready;

  @override
  Widget? get preview => _ready
      ? const ColoredBox(
          color: Color(0xFF103B21),
          child: Center(child: Text('Preview')),
        )
      : null;

  @override
  Future<void> initialize() async {
    // The screen may ask twice while it rebuilds; only the first one counts.
    if (_initializing || _ready) return;
    _initializing = true;
    initializeCalls++;
    try {
      if (initializeError != null) throw initializeError!;
      _ready = true;
    } finally {
      _initializing = false;
    }
  }

  @override
  Future<Uint8List> takePicture() async {
    if (takePictureError != null) throw takePictureError!;
    return pictureBytes ?? Uint8List(64);
  }

  @override
  Future<Uint8List?> pickFromGallery() async => galleryBytes;

  @override
  Future<void> dispose() async {
    disposed = true;
    _ready = false;
  }
}
