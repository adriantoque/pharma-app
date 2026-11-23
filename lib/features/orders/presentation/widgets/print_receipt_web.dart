// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Delegates to the browser's print dialog on web.
void printReceipt() {
  html.window.print();
}