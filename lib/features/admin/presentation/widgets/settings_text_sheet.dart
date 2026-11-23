import 'package:flutter/material.dart';

/// Opens a one-field text editor and hands back what the admin typed.
///
/// Returns the trimmed value, or null when the sheet was dismissed -- the
/// caller cannot tell "cancelled" from "cleared" through the return value
/// alone, and does not need to: an empty result means the field is cleared,
/// which is a legitimate outcome of opening the editor and wiping it.
///
/// One field per sheet, not a form: the settings screen is already a list,
/// and re-listing everything inside a sheet would make two places to keep in
/// step. Mirrors `showUserEditSheet`'s chrome so sheets across the admin
/// workspace feel like one control.
Future<String?> showSettingsTextSheet(
  BuildContext context, {
  required String title,
  required String initialValue,
  String? helper,
  TextInputType? keyboardType,
  String? Function(String value)? validate,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (_) => _SettingsTextSheet(
      title: title,
      initialValue: initialValue,
      helper: helper,
      keyboardType: keyboardType,
      validate: validate,
    ),
  );
}

class _SettingsTextSheet extends StatefulWidget {
  const _SettingsTextSheet({
    required this.title,
    required this.initialValue,
    required this.helper,
    required this.keyboardType,
    required this.validate,
  });

  final String title;
  final String initialValue;
  final String? helper;
  final TextInputType? keyboardType;
  final String? Function(String value)? validate;

  @override
  State<_SettingsTextSheet> createState() => _SettingsTextSheetState();
}

class _SettingsTextSheetState extends State<_SettingsTextSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  String? _problem;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final problem = widget.validate?.call(_controller.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: widget.keyboardType,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            onChanged: (_) {
              // A problem stays only while the text stays wrong. Clearing it
              // on every keystroke keeps the error honest without having to
              // re-validate silently on every change.
              if (_problem != null) setState(() => _problem = null);
            },
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              helperText: widget.helper,
              errorText: _problem,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
