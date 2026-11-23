import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a CSV in a scrollable, selectable dialog with a copy-to-clipboard
/// action.
///
/// Shared by Inventory and Expiring Meds. Both build a CSV in memory and have
/// nowhere to write it -- there is no file-system dependency in the app -- so
/// the clipboard is the export: the dialog is the deliverable, and a user
/// pastes the sheet into whatever they keep records in.
///
/// [title] names the sheet being exported; [csv] is the whole document.
Future<void> showCsvExportDialog(
  BuildContext context, {
  required String title,
  required String csv,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: SelectableText(
            csv,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: csv));
            Navigator.of(dialogContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CSV copied to clipboard')),
            );
          },
          child: const Text('Copy to clipboard'),
        ),
      ],
    ),
  );
}
