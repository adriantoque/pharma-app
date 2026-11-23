import 'package:flutter/material.dart';

/// Shows a short error message at the bottom of the screen.
///
/// Keeps every call site a single line: `SnackbarHelper.showError(context, message)`.
class SnackbarHelper {
  SnackbarHelper._();

  /// Shows [message] as an error snackbar for [duration].
  static void showError(
    BuildContext context, [
    String? message,
    Duration duration = const Duration(seconds: 4),
  ]) {
    final text = message ?? 'Something went wrong.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: Colors.redAccent,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Shows [message] as a success snackbar for [duration].
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
