import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/pdf_receipt_service.dart';
import '../../data/models/receipt_model.dart';

/// Saves, shares, and opens a generated receipt PDF.
///
/// The interface is kept free of Flutter so a widget test can drive the
/// receipt flow against an in-memory fake without a file system or a share
/// sheet behind it.
abstract class ReceiptRepository {
  /// Renders [receipt] to a PDF document.
  ///
  /// The rendering itself lives in [PdfReceiptService]; this method owns the
  /// decision of *when* to render and what to do with the bytes.
  Future<pw.Document> render(ReceiptModel receipt);

  /// Writes [document] to the app's documents directory under [fileName] and
  /// returns the resulting [File].
  Future<File> save(pw.Document document, String fileName);

  /// Opens the system share sheet for [file], so the customer can receive the
  /// receipt by message, email, or Bluetooth.
  Future<void> share(File file);

  /// Opens [file] with the device's default PDF viewer.
  Future<void> open(File file);

  /// Deletes [file] if it exists. A no-op when the file is already gone.
  Future<void> delete(File file);
}

/// The real implementation: renders through [PdfReceiptService], writes to
/// the documents directory via [path_provider], shares through
/// [share_plus], and opens through [open_filex].
class ReceiptRepositoryImpl implements ReceiptRepository {
  ReceiptRepositoryImpl();

  @override
  Future<pw.Document> render(ReceiptModel receipt) async {
    return PdfReceiptService.instance.build(receipt);
  }

  @override
  Future<File> save(pw.Document document, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    final bytes = await document.save();
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Future<void> share(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Your PharmaGuide receipt (${file.path.split('/').last})',
      ),
    );
  }

  @override
  Future<void> open(File file) async {
    await OpenFilex.open(file.path);
  }

  @override
  Future<void> delete(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone — nothing to do.
    }
  }
}

/// An in-memory implementation for tests and previews. Holds the last
/// rendered document and "saved" file in memory instead of on disk.
class ReceiptRepositoryFake implements ReceiptRepository {
  ReceiptRepositoryFake();

  pw.Document? _lastDocument;
  String? _lastFileName;
  bool _shareCalled = false;
  bool _openCalled = false;

  /// The last document rendered, for a test to assert on.
  pw.Document? get lastDocument => _lastDocument;

  /// The last file name "saved", for a test to assert on.
  String? get lastFileName => _lastFileName;

  /// Whether [share] was called since the last reset.
  bool get shareCalled => _shareCalled;

  /// Whether [open] was called since the last reset.
  bool get openCalled => _openCalled;

  void reset() {
    _lastDocument = null;
    _lastFileName = null;
    _shareCalled = false;
    _openCalled = false;
  }

  @override
  Future<pw.Document> render(ReceiptModel receipt) async {
    _lastDocument = await PdfReceiptService.instance.build(receipt);
    return _lastDocument!;
  }

  @override
  Future<File> save(pw.Document document, String fileName) async {
    _lastDocument = document;
    _lastFileName = fileName;
    return File('/tmp/receipt_fake/$fileName');
  }

  @override
  Future<void> share(File file) async {
    _shareCalled = true;
  }

  @override
  Future<void> open(File file) async {
    _openCalled = true;
  }

  @override
  Future<void> delete(File file) async {
    // Nothing on disk to delete.
  }
}
