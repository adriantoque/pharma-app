import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/models/receipt_model.dart';
import '../../data/repositories/receipt_repository.dart';

/// The state behind generating, saving, sharing, and opening a receipt PDF.
///
/// Registered above the router alongside the other order providers, so a
/// receipt survives the screen that asked for it and a second screen can
/// pick up the same saved file without regenerating.
class ReceiptProvider extends ChangeNotifier {
  ReceiptProvider({required this._repository});

  final ReceiptRepository _repository;

  bool _isGenerating = false;
  File? _savedFile;
  String? _error;
  bool _disposed = false;

  /// True between `generate()` returning and the future settling.
  bool get isGenerating => _isGenerating;

  /// The file most recently saved to disk, or null if none has been saved.
  File? get savedFile => _savedFile;

  /// Why the last generation or save failed, if anything.
  String? get error => _error;

  /// Whether a receipt is saved and ready to share or open.
  bool get hasSavedFile => _savedFile != null && _savedFile!.existsSync();

  /// Generates the PDF for [receipt] and saves it to the documents directory.
  ///
  /// Returns true on success. On failure, [error] is populated and the
  /// provider notifies so the screen can show a message.
  Future<bool> generateAndSave(ReceiptModel receipt) async {
    _isGenerating = true;
    _error = null;
    _safeNotify();

    try {
      final document = await _repository.render(receipt);
      _savedFile = await _repository.save(document, receipt.fileName);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isGenerating = false;
      _safeNotify();
    }
  }

  /// Opens the system share sheet for the last saved file.
  ///
  /// Returns false when nothing has been saved yet.
  Future<bool> share() async {
    final file = _savedFile;
    if (file == null || !file.existsSync()) return false;
    await _repository.share(file);
    return true;
  }

  /// Opens the last saved file with the device's default PDF viewer.
  ///
  /// Returns false when nothing has been saved yet.
  Future<bool> open() async {
    final file = _savedFile;
    if (file == null || !file.existsSync()) return false;
    await _repository.open(file);
    return true;
  }

  /// Forgets the saved file so the screen can regenerate a fresh one.
  void clear() {
    _savedFile = null;
    _error = null;
    _safeNotify();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
