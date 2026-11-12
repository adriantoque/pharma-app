/// Best-effort browser print helper.
///
/// On web this delegates to `window.print()` so the receipt can be printed or
/// saved as a PDF through the browser's print dialog. On other platforms (and
/// in tests) it is a no-op so the widget compiles and runs everywhere.
export 'print_receipt_stub.dart' if (dart.library.html) 'print_receipt_web.dart';