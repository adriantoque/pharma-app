import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Widget;
import 'package:image_picker/image_picker.dart';

import '../domain/prescription_camera.dart';
import '../domain/prescription_recognizer.dart';

/// The real camera: live preview and capture through the `camera` plugin, and a
/// gallery fallback through `image_picker`.
///
/// This is the only file that imports those plugins, so the Scan tab works in a
/// widget test against [PrescriptionCamera].
class CameraPrescriptionCamera implements PrescriptionCamera {
  CameraController? _controller;
  CameraDescription? _back;
  bool _disposed = false;

  @override
  bool get isSupported => !kIsWeb;

  @override
  bool get isReady => _controller?.value.isInitialized ?? false;

  /// The live preview widget. Null until [initialize] has opened the camera.
  @override
  Widget? get preview =>
      _controller == null ? null : CameraPreview(_controller!);

  @override
  Future<void> initialize() async {
    _checkUsable();
    if (isReady) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw PrescriptionRecognitionException(
          'No camera was found on this device. You can still pick a photo of '
          'the prescription from your gallery.',
        );
      }
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back && _back == null) {
          _back = camera;
        }
      }
      _back ??= cameras.first;

      final controller = CameraController(
        _back == null ? cameras.first : _back!,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
    } on MissingPluginException {
      _controller = null;
      throw PrescriptionRecognitionException(
        'The camera is not available on this platform.',
        isUnsupportedPlatform: true,
      );
    } on CameraException catch (error) {
      _controller = null;
      if (error.code == 'CameraAccessDenied' ||
          error.code == 'CameraAccessDeniedWithoutPrompt' ||
          error.code == 'cameraPermission' ||
          error.code == 'CameraPermissions') {
        throw PrescriptionRecognitionException(
          'The camera is switched off for PharmaGuide. Allow it in Settings, '
          'or pick a photo of the prescription from your gallery instead.',
          isPermissionDenied: true,
        );
      }
      throw PrescriptionRecognitionException(
        'The camera could not start. ${error.description ?? error.code}.',
      );
    }
  }

  @override
  Future<Uint8List> takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw PrescriptionRecognitionException('The camera is not open.');
    }

    final XFile picture;
    try {
      picture = await controller.takePicture();
    } on CameraException catch (error) {
      throw PrescriptionRecognitionException(
        'The photo could not be taken. (${error.code})',
      );
    } on MissingPluginException {
      throw PrescriptionRecognitionException(
        'The camera is not available on this platform.',
        isUnsupportedPlatform: true,
      );
    }

    try {
      return await picture.readAsBytes();
    } finally {
      // capture stays out of the user's gallery; it is OCR fuel, not a photo.
      try {
        final file = File(picture.path);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // The plugin may still hold it; the cache will reclaim it.
      }
    }
  }

  /// Works even when the camera never started: a denied permission or a missing
  /// back camera must not take the fallback away.
  @override
  Future<Uint8List?> pickFromGallery() async {
    _checkUsable();
    final picker = ImagePicker();
    try {
      final picture = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 92,
      );
      if (picture == null) return null;
      return await picture.readAsBytes();
    } on MissingPluginException {
      throw PrescriptionRecognitionException(
        'Picking a photo is not available on this platform.',
        isUnsupportedPlatform: true,
      );
    } on PlatformException catch (error) {
      final message = error.code == 'photo_access_denied'
          ? 'Photos are switched off for PharmaGuide. Allow them in Settings to '
                'pick a prescription.'
          : 'The photo could not be read. (${error.code})';
      throw PrescriptionRecognitionException(message);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final controller = _controller;
    _controller = null;
    if (controller == null) return;

    try {
      await controller.dispose();
    } on CameraException {
      // Nothing native to release.
    }
  }

  void _checkUsable() {
    if (_disposed) {
      throw StateError('This camera has already been disposed.');
    }
    if (!isSupported) {
      throw PrescriptionRecognitionException(
        'The camera is not available on this platform.',
        isUnsupportedPlatform: true,
      );
    }
  }
}
