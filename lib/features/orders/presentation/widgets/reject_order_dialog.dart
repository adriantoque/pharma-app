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

  /// Key for the free-text field in the "Other" popup.
  static const Key otherReasonFieldKey = Key('rejectOtherReasonField');

  /// Key for the "Other" popup's Save button, so tests can assert when it is
  /// disabled.
  static const Key otherReasonSaveKey = Key('rejectOtherReasonSave');

  /// Key for the confirm button, so tests can assert when it is disabled.
  static const Key confirmKey = Key('rejectConfirmButton');

  @override
  State<RejectOrderDialog> createState() => _RejectOrderDialogState();
}

class _RejectOrderDialogState extends State<RejectOrderDialog> {
  static const String _other = 'Other';

  /// The picked preset, or [_other] when the free-text option is chosen.
  String? _selected;

  /// The text typed into the "Other" popup, kept so Reject has something to
  /// store. Null until the user has saved a reason there.
  String? _otherReason;

  bool get _isOther => _selected == _other;

  /// The reason that will be stored, or null while none has been given.
  String? get _reason => _isOther ? _otherReason : _selected;

  bool get _canConfirm => _reason != null;

  void _select(String value) => setState(() => _selected = value);

  /// Opens the dedicated typing popup for the "Other" option.
  ///
  /// The free text is collected in a dialog of its own rather than as a field
  /// below the chips: it keeps this dialog a plain reason picker and gives the
  /// keyboard a surface that scrolls on its own.
  Future<void> _pickOtherReason() async {
    final typed = await showDialog<String>(
      context: context,
      builder: (_) => _OtherReasonDialog(initial: _otherReason),
    );
    if (!mounted || typed == null) return;
    setState(() {
      _otherReason = typed;
      _selected = _other;
    });
  }

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
      // Wider than the default gutter so the reason chips and the typing box
      // have room on a 360dp phone instead of the field being squeezed narrow.
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      // Let the dialog scroll when the keyboard opens (the "Other" field
      // autofocuses), rather than crushing the field off the bottom.
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Order #${widget.orderId} will be rejected. '
            'Choose a reason to keep with the order.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colours.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // The choices sit close together as one block, so the picked reason
          // reads as the next step rather than a separate section.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preset in RejectOrderDialog.presets)
                _ReasonChip(
                  label: preset,
                  selected: _selected == preset,
                  onSelected: () => _select(preset),
                ),
              _ReasonChip(
                label: _other,
                selected: _isOther,
                onSelected: _pickOtherReason,
              ),
            ],
          ),
          if (_isOther && _otherReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '“$_otherReason”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colours.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
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

/// A preset reason, rendered compactly so the choices read as one tight block.
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      // Compact density and a shrink-wrapped tap target pull the chips in
      // closer; the label padding trims the default chip gutter.
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

/// The popup that collects the free-text reason for the "Other" option.
///
/// Pops with the trimmed text on Save and `null` on Cancel. Save stays disabled
/// until something is typed, so an empty reason can never be stored.
class _OtherReasonDialog extends StatefulWidget {
  const _OtherReasonDialog({this.initial});

  /// Text to pre-fill when the user is editing a reason already saved.
  final String? initial;

  @override
  State<_OtherReasonDialog> createState() => _OtherReasonDialogState();
}

class _OtherReasonDialogState extends State<_OtherReasonDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );

  String get _text => _controller.text.trim();

  bool get _canSave => _text.isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(_text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Other reason'),
      content: TextField(
        key: RejectOrderDialog.otherReasonFieldKey,
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        // Rebuild so Save enables on the first character.
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Reason',
          hintText: 'e.g. damaged box',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: RejectOrderDialog.otherReasonSaveKey,
          onPressed: _canSave ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
