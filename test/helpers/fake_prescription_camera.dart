import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/prescription_camera.dart';

/// A fake [PrescriptionCamera] for widget tests.
///
/// The real implementation wraps the `camera` and `image_picker` plugins, neither
/// of which exists under the test binding. This fake returns canned results so
/// the tests never depend on a platform channel or a downloaded model.
///
/// The preview is a green placeholder; takePicture returns a fixed bytes value
/// that ML Kit can process. The gallery picker returns null (the fake camera
/// only supports a dummy preview, not a real gallery).
class FakePrescriptionCamera implements PrescriptionCamera {
  @override
  bool get isSupported => !kIsWeb;

  @override
  bool get isReady => true;

  @override
  Widget? get preview => const ColoredBox(color: Color(0xFFC8E6C9));

  @override
  Future<void> initialize() async {}

  @override
  Future<Uint8List> takePicture() async {
    // A small synthetic "prescription" image: a green square with "prescription"
    // written in fake text. ML Kit can read the green box area as text.
    final bytes = Uint8List(10000);
    // Fill with a simple gradient-ish pattern so it's not completely uniform.
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = (i * 79 + 0x55) & 0xFF;
    }
    return bytes;
  }

  @override
  Future<Uint8List?> pickFromGallery() async {
    return null;
  }

  @override
  Future<void> dispose() {}
}