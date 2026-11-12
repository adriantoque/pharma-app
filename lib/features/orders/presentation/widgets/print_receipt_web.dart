import 'dart:html' as html;

/// Delegates to the browser's print dialog on web.
void printReceipt() {
  html.window.print();
}