import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Offset, Widget;

import '../domain/prescription_camera.dart';
import '../domain/prescription_recognizer.dart';

/// The real camera: live preview and capture through the `camera` plugin.
///
/// It also carries the device side of the live scanner: the preview torch for
/// dim counters, and the preview as a throttled stream of frames already in the
/// pixel layout each platform's recognizer eats — NV21 on Android (converted
/// from the YUV the plugin streams), BGRA untouched on iOS.
///
/// This is the only file that imports those plugins, so the Scan tab works in a
/// widget test against [PrescriptionCamera].
class CameraPrescriptionCamera implements PrescriptionCamera {
  CameraController? _controller;
  CameraDescription? _back;
  bool _disposed = false;

  /// Whether the live scanner is currently busy processing a frame.
  bool _liveFrameBusy = false;

  /// Whether the preview is streaming yet — one attempt at [startImageStream],
  /// not one attempt per frame.
  bool _streaming = false;

  /// The live scanner's callback, held so the stream can pause itself around a
  /// deliberate capture and come back without being asked twice.
  void Function(PrescriptionFrame frame)? _onFrame;

  /// The zoom range the device reported when it opened, cached so the preview's
  /// zoom controls can clamp against it without a platform call per gesture.
  double? _minZoom;
  double? _maxZoom;

  /// How fast frames are converted and forwarded. A stream arrives at
  /// camera-like rates while a frame can only be read at a fraction of that,
  /// so delivering every one would spend copies the recognizer's own queue
  /// would skip anyway. The reader throttles again on top of this.
  static const Duration _frameInterval = Duration(milliseconds: 200);

  final Stopwatch _frameThrottle = Stopwatch();

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

      // Text lives or dies on resolution: a 4K still holds dose lines a 1080p
      // one turns to noise, so the highest preset is tried first and the chain
      // steps down only when the device refuses the one above it.
      const presets = [
        ResolutionPreset.max,
        ResolutionPreset.ultraHigh,
        ResolutionPreset.veryHigh,
      ];
      CameraException? lastFailure;
      for (final preset in presets) {
        final controller = CameraController(
          _back == null ? cameras.first : _back!,
          preset,
          enableAudio: false,
        );
        try {
          await controller.initialize();
          _controller = controller;
          lastFailure = null;
          break;
        } on CameraException catch (error) {
          // A refused permission is not a resolution the next preset can fix,
          // so it climbs straight to the outer handler and its permission
          // message instead of being spent on a doomed retry.
          if (error.code == 'CameraAccessDenied' ||
              error.code == 'CameraAccessDeniedWithoutPrompt' ||
              error.code == 'cameraPermission' ||
              error.code == 'CameraPermissions') {
            rethrow;
          }
          lastFailure = error;
          try {
            await controller.dispose();
          } on CameraException {
            // Nothing native to release for a controller that never opened.
          }
        }
      }
      final controller = _controller;
      if (controller == null) {
        final error = lastFailure;
        if (error != null) {
          throw PrescriptionRecognitionException(
            'The camera could not start. ${error.description ?? error.code}.',
          );
        }
        throw PrescriptionRecognitionException('The camera could not start.');
      }

      // The automatic focus and metering the scanner wants are the camera
      // defaults, but asking for them by name means a device left in another
      // mode by a previous app still lands where the scan expects.
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setExposureMode(ExposureMode.auto);
      } on CameraException {
        // A device that refuses the mode still frames and captures; the tap-
        // to-focus capability below reports what actually works.
      }

      // The zoom range is a device fact, asked once and held: the preview's
      // pinch gesture clamps against these on every update, and a camera
      // without zoom optics reports a range that says so.
      try {
        _minZoom = await controller.getMinZoomLevel();
        _maxZoom = await controller.getMaxZoomLevel();
      } on CameraException {
        _minZoom = null;
        _maxZoom = null;
      }
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

    // Android refuses a still capture while the preview frames stream, so the
    // live scanner pauses around it — and comes back on its own if it was the
    // thing streaming, without the tab having to start it twice.
    final wasStreaming = _streaming;
    if (wasStreaming) await stopLiveFrames();

    final XFile picture;
    try {
      picture = await controller.takePicture();
    } on CameraException catch (error) {
      if (wasStreaming) unawaited(_resumeStream(controller));
      throw PrescriptionRecognitionException(
        'The photo could not be taken. (${error.code})',
      );
    } on MissingPluginException {
      throw PrescriptionRecognitionException(
        'The camera is not available on this platform.',
        isUnsupportedPlatform: true,
      );
    } finally {
      if (wasStreaming && !_disposed) unawaited(_resumeStream(controller));
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

  /// Puts the stream back on after a deliberate capture paused it.
  ///
  /// Quiet about failure on purpose: losing the live view is a downgrade the
  /// tab can work around with the Scan button, not an error to raise.
  Future<void> _resumeStream(CameraController controller) async {
    if (_disposed || _onFrame == null || _streaming) return;
    try {
      await controller.startImageStream(_deliverFrame);
      _streaming = true;
    } on CameraException {
      // Deliberate scanning still works; live just went quiet.
    }
  }

  @override
  bool get supportsTorch => true;

  @override
  Future<void> setTorch(bool enabled) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
    } on CameraException catch (error) {
      // Some cameras fire a flash for a photo but cannot hold a steady light,
      // which is a device fact rather than a bug — the toggle reports it and
      // the tab decides how quiet to stay about it.
      throw PrescriptionRecognitionException(
        'The torch could not be switched. (${error.code})',
      );
    }
  }

  @override
  bool get supportsLiveFrames => isSupported;

  @override
  void setLiveBusy(bool busy) {
    _liveFrameBusy = busy;
  }

  @override
  bool get supportsZoom => _minZoom != null && _maxZoom != null;

  @override
  Future<double> get minZoomLevel async => _minZoom ?? 1.0;

  @override
  Future<double> get maxZoomLevel async => _maxZoom ?? 1.0;

  @override
  Future<void> setZoomLevel(double zoom) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final min = _minZoom;
    final max = _maxZoom;
    // Clamped here as well as in the preview's gesture: a gesture can outrun
    // the cache on a device whose range was probed before optics settled.
    final clamped = zoom.clamp(min ?? zoom, max ?? zoom).toDouble();
    try {
      await controller.setZoomLevel(clamped);
    } on CameraException {
      // A refused zoom is a downgrade to the framing the user already had,
      // not an error worth a card over the preview.
    }
  }

  @override
  bool get supportsTapToFocus =>
      _controller?.value.focusPointSupported ?? false;

  @override
  Future<void> setFocusPoint(double x, double y) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final point = Offset(
        x.clamp(0.0, 1.0).toDouble(),
        y.clamp(0.0, 1.0).toDouble(),
      );
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
    } on CameraException {
      // The tap asked for a focus the device will not give; the preview keeps
      // its whole-frame focus and the next tap can try again.
    }
  }

  @override
  Future<void> clearFocusPoint() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setFocusPoint(null);
      await controller.setExposurePoint(null);
    } on CameraException {
      // Same quietness as setting: a device that refused the point refuses
      // the clearing too, and nothing the user can see depends on either.
    }
  }

  @override
  Future<void> startLiveFrames(
    void Function(PrescriptionFrame frame) onFrame,
  ) async {
    _checkUsable();
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw PrescriptionRecognitionException('The camera is not open.');
    }
    _onFrame = onFrame;
    if (_streaming) return;
    try {
      await controller.startImageStream(_deliverFrame);
      _streaming = true;
    } on CameraException catch (error) {
      _onFrame = null;
      throw PrescriptionRecognitionException(
        'Live scanning could not start. (${error.code})',
      );
    }
  }

  @override
  Future<void> stopLiveFrames() async {
    _onFrame = null;
    if (!_streaming) return;
    _streaming = false;
    try {
      await _controller?.stopImageStream();
    } on CameraException {
      // The preview is already gone for other reasons; nothing to unwind.
    }
  }

  /// Converts a streamed frame to the layout the recognizer eats, paced by the
  /// throttle, and hands it to the live scanner if one is still listening.
  void _deliverFrame(CameraImage image) {
    if (_disposed || !_streaming) return;
    // Skip the conversion entirely while a frame is being read: the frame would
    // only be discarded, and converting it only spends a memcpy and a buffer.
    if (_liveFrameBusy) return;
    if (_frameThrottle.isRunning && _frameThrottle.elapsed < _frameInterval) {
      return;
    }
    _frameThrottle
      ..start()
      ..reset();
    final frame = _convert(image);
    final onFrame = _onFrame;
    if (frame != null && onFrame != null) onFrame(frame);
  }

  /// One preview frame, in the recognizer's native pixel layout per platform.
  ///
  /// Null means "nothing recognisable to ML Kit here — skip it", which is
  /// quieter than failing a mode the tab already treats as an upgrade.
  PrescriptionFrame? _convert(CameraImage image) {
    switch (image.format.group) {
      case ImageFormatGroup.bgra8888:
        // iOS streams BGRA exactly as ML Kit wants it: one plane, per-row
        // stride reported, nothing to copy or repack.
        return PrescriptionFrame(
          bytes: image.planes[0].bytes,
          bytesPerRow: image.planes[0].bytesPerRow,
          width: image.width,
          height: image.height,
          rotationDegrees: _rotation,
        );
      case ImageFormatGroup.nv21:
        // Some Android streams hand over native NV21 already — pass it on.
        return PrescriptionFrame(
          bytes: image.planes[0].bytes,
          bytesPerRow: image.width,
          width: image.width,
          height: image.height,
          rotationDegrees: _rotation,
        );
      case ImageFormatGroup.yuv420:
        // The Android default: three planar YUV surfaces that must become one
        // interleaved NV21 buffer before ML Kit will accept them.
        return _nv21Frame(image);
      case ImageFormatGroup.jpeg:
      case ImageFormatGroup.unknown:
        return null;
    }
  }

  /// YUV planar to NV21 packed: luma block first, then interleaved V,U.
  ///
  /// Strides are honoured row by row and per pixel, so cameras that pad rows
  /// or step chroma two bytes still come out in the exact layout ML Kit's
  /// Android side reads. The copies stay inside the throttle's budget: a
  /// convert is a couple of memcpys, not a recognition.
  PrescriptionFrame? _nv21Frame(CameraImage image) {
    if (image.planes.length < 3) return null;
    final width = image.width;
    final height = image.height;
    final y = image.planes[0];
    final u = image.planes[1];
    final v = image.planes[2];

    final packed = Uint8List(width * height + (width ~/ 2) * (height ~/ 2) * 2);
    var at = 0;
    for (var row = 0; row < height; row++) {
      packed.setRange(at, at + width, y.bytes, row * y.bytesPerRow);
      at += width;
    }
    final chromaRows = height ~/ 2;
    final chromaCols = width ~/ 2;
    final uStep = u.bytesPerPixel ?? 1;
    final vStep = v.bytesPerPixel ?? 1;
    for (var row = 0; row < chromaRows; row++) {
      for (var col = 0; col < chromaCols; col++) {
        packed[at++] = v.bytes[row * v.bytesPerRow + col * vStep];
        packed[at++] = u.bytes[row * u.bytesPerRow + col * uStep];
      }
    }
    return PrescriptionFrame(
      bytes: packed,
      bytesPerRow: width,
      width: width,
      height: height,
      rotationDegrees: _rotation,
    );
  }

  /// How the sensor sits in the device — what the recognizer must be told so
  /// a held-vertically phone reads text the right way up.
  int get _rotation => _back?.sensorOrientation ?? 0;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _onFrame = null;
    _streaming = false;

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
