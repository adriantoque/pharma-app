import 'package:flutter/material.dart';

/// Asks the cashier why an order is being rejected.
///
/// Offers the reasons a pharmacy counter actually rejects an order for, plus an
/// "Other" option with a free-text field. A reason is required -- the Reject
/// button stays disabled until one is given -- because the reason is stored with
/// the order and shown on the Order History screen.
///
/// Pops with the chosen reason on confirm, and with `null` on cancel.
class RejectOrderDialog extends StatefulWidget {
  const RejectOrderDialog({super.key, required this.orderId});

  /// The order being rejected, used in the dialog's copy.
  final String orderId;

  /// The quick picks offered before the free-text "Other" option.
  static const List<String> presets = [
    'Out of stock',
    'Expired or damaged',
    'Wrong medicine ordered',
    'Customer cancelled',
    'Prescription required',
  ];

  /// Key for the free-text field, so tests can type into it.
  static const Key otherFieldKey = Key('rejectReasonField');

  /// Key for the confirm button, so tests can assert when it is disabled.
  static const Key confirmKey = Key('rejectConfirmButton');

  @override
  State<RejectOrderDialog> createState() => _RejectOrderDialogState();
}

class _RejectOrderDialogState extends State<RejectOrderDialog> {
  static const String _other = 'Other';

  final TextEditingController _otherController = TextEditingController();

  /// The picked preset, or [_other] when the free-text option is chosen.
  String? _selected;

  bool get _isOther => _selected == _other;

  /// The reason that will be stored, or null while none has been given.
  String? get _reason {
    if (_isOther) {
      final typed = _otherController.text.trim();
      return typed.isEmpty ? null : typed;
    }
    return _selected;
  }

  bool get _canConfirm => _reason != null;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _select(String value) => setState(() => _selected = value);

  void _confirm() {
    final reason = _reason;
    if (reason == null) return;
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colours = theme.colorScheme;

    return AlertDialog(
      icon: CircleAvatar(
        backgroundColor: colours.errorContainer,
        child: Icon(Icons.block, color: colours.onErrorContainer),
      ),
      title: const Text('Reject order'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Order #${widget.orderId} will be marked as rejected. '
              'Choose a reason to keep with the order.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colours.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in RejectOrderDialog.presets)
                  ChoiceChip(
                    label: Text(preset),
                    selected: _selected == preset,
                    onSelected: (_) => _select(preset),
                  ),
                ChoiceChip(
                  label: const Text(_other),
                  selected: _isOther,
                  onSelected: (_) => _select(_other),
                ),
              ],
            ),
            if (_isOther) ...[
              const SizedBox(height: 12),
              TextField(
                key: RejectOrderDialog.otherFieldKey,
                controller: _otherController,
                autofocus: true,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                // Rebuild so the Reject button enables on the first character.
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g. box was damaged on arrival',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: RejectOrderDialog.confirmKey,
          onPressed: _canConfirm ? _confirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: colours.error,
            foregroundColor: colours.onError,
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
