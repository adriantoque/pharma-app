import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../orders/presentation/providers/order_provider.dart';
import '../../data/models/medicine_model.dart';

/// Asks how many units of [medicine] to add, and returns that count.
///
/// Returns null if the sheet is dismissed, so the caller can tell "added
/// nothing" apart from "added zero" without the sheet having to guess. The
/// sheet deliberately does not touch [OrderProvider] itself: keeping it a pure
/// input means it can be opened from anywhere, and the row that opened it is the
/// one that decides what adding means.
///
/// The ceiling is [OrderProvider.capFor], so the sheet follows the stock on the
/// shelf rather than the app-wide 99 limit, and the two cannot drift apart.
Future<int?> showQuantitySheet(
  BuildContext context, {
  required MedicineModel medicine,
}) {
  // Nothing on the shelf, so there is no quantity worth asking for -- and the
  // clamp range inside the sheet would be 1..0, which throws rather than
  // returning anything. A search row disables its add button for these items, so
  // this is the backstop for a caller that forgets to check.
  if (OrderProvider.capFor(medicine) < OrderProvider.minQuantity) {
    return Future<int?>.value();
  }

  return showModalBottomSheet<int>(
    context: context,
    // The sheet is taller than a default sheet on a short screen, and the
    // keyboard would cover the confirm button without this.
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (context) => _QuantitySheet(medicine: medicine),
  );
}

class _QuantitySheet extends StatefulWidget {
  const _QuantitySheet({required this.medicine});

  final MedicineModel medicine;

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  /// Most units of this item an order may hold: its stock, capped by the
  /// app-wide ceiling. Read once, since the shelf level is fixed for the life of
  /// the sheet and a value that changed under the user mid-edit would be worse
  /// than a stale one.
  late final int _max = OrderProvider.capFor(widget.medicine);

  late final TextEditingController _controller = TextEditingController(
    text: OrderProvider.minQuantity.toString(),
  );

  @override
  void initState() {
    super.initState();
    // Puts the caret in the number so a typed amount replaces it instead of
    // appending to a value the user did not choose.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The number as typed, or null when the field is empty or mid-edit. Null is
  /// deliberately not treated as 1: someone who has cleared the box to type a
  /// new amount has not asked for one unit.
  int? get _typed => int.tryParse(_controller.text.trim());

  /// What the field currently stands for, which is also what the stepper moves
  /// from and what confirm returns.
  int get _current => _typed ?? OrderProvider.minQuantity;

  int get _effective => _current.clamp(OrderProvider.minQuantity, _max);

  void _step(int delta) {
    final next = _current + delta;
    // Clamped rather than ignored so the button at the limit looks inert instead
    // of appearing broken.
    setState(() {
      _controller.text = next.clamp(OrderProvider.minQuantity, _max).toString();
    });
  }

  void _confirm() => Navigator.of(context).pop(_effective);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atMin = _current <= OrderProvider.minQuantity;
    final atMax = _current >= _max;

    return Padding(
      // Bottom inset for the keyboard, exactly as the auth sheet does it: the
      // sheet is not resizable, so the padding is what lifts the confirm button
      // clear of the keyboard.
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
            widget.medicine.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.medicine.formattedPrice,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                key: const Key('stepperDecrease'),
                onPressed: atMin ? null : () => _step(-1),
                icon: const Icon(Icons.remove),
                tooltip: 'One fewer',
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 88,
                child: TextField(
                  // Keyed because the search page behind the sheet has a field
                  // of its own, so find.byType(TextField) is ambiguous while the
                  // sheet is open.
                  key: const Key('quantityField'),
                  controller: _controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  // Digits only, and two of them, which is what makes 99 the
                  // ceiling without clamping on every keystroke.
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  style: theme.textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _confirm(),
                ),
              ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                key: const Key('stepperIncrease'),
                onPressed: atMax ? null : () => _step(1),
                icon: const Icon(Icons.add),
                tooltip: 'One more',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            // Says *why* the ceiling is where it is. A user who cannot type 50
            // because the shelf holds three is better served by that fact than by
            // a number they were never told the meaning of.
            _max < OrderProvider.maxQuantity
                ? 'Only $_max in stock'
                : 'Maximum $_max per item',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: widget.medicine.isLowStock
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _confirm, child: const Text('Add to order')),
        ],
      ),
    );
  }
}
