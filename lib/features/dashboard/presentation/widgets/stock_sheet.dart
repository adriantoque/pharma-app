import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../search/presentation/providers/medicine_provider.dart';

/// Asks for a shelf count for [medicine] and records it.
///
/// Returns the count that was recorded, or null if the sheet was dismissed.
///
/// "Not counted" is a first-class answer here, not an absence of one, so the
/// sheet has a control for it. Reaching it any other way would mean editing a
/// field in the console, and a count that can only be removed by a developer is
/// a count that will be wrong within a month. The distinction matters because
/// only a real zero blocks an order, so a staff member who cannot get *back* to
/// uncounted would have no way to undo a miscount.
Future<int?> showStockSheet(
  BuildContext context, {
  required MedicineModel medicine,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (context) => _StockSheet(medicine: medicine),
  );
}

class _StockSheet extends StatefulWidget {
  const _StockSheet({required this.medicine});

  final MedicineModel medicine;

  @override
  State<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends State<_StockSheet> {
  /// Seeded with whatever is already recorded, so saving without typing leaves
  /// the count alone rather than silently replacing it with a 1.
  late final TextEditingController _controller = TextEditingController(
    text: widget.medicine.stock?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The number as typed, or null when the field is empty or half-typed.
  ///
  /// Null is not treated as 0. Someone who has cleared the box to type a new
  /// count has not said the shelf is empty, and committing that reading would
  /// mark a stocked product out of stock.
  int? get _typed => int.tryParse(_controller.text.trim());

  /// The count the field stands for, ignoring the app-wide order ceiling.
  ///
  /// No ceiling here: the count on a shelf is whatever the shelf holds, and a
  /// product stocked at 400 must be recordable. The 99-per-order limit is an
  /// order constraint, not a stock one, and reusing it here would make a correct
  /// count impossible to enter.
  int get _effective => _typed ?? 0;

  void _step(int delta) {
    setState(() {
      _controller.text = (_effective + delta).clamp(0, _maxCount).toString();
    });
  }

  /// A generous ceiling that still catches a stuck key.
  static const int _maxCount = 99999;

  void _save() {
    final stock = _typed;
    if (stock == null) return;
    context.read<MedicineProvider>().setStock(widget.medicine, stock);
    Navigator.of(context).pop(stock);
  }

  /// Puts the line back to "Not counted".
  Future<void> _clear() async {
    await context.read<MedicineProvider>().setStock(widget.medicine, null);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atMin = _effective <= 0;
    final atMax = _effective >= _maxCount;
    final wasCounted = widget.medicine.stock != null;

    return Padding(
      // Bottom inset for the keyboard, as in the quantity sheet: these sheets
      // are not resizable, so the padding is what lifts the controls clear of
      // it.
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
                key: const Key('stockDecrease'),
                onPressed: atMin ? null : () => _step(-1),
                icon: const Icon(Icons.remove),
                tooltip: 'One fewer',
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 112,
                child: TextField(
                  key: const Key('stockField'),
                  controller: _controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  style: theme.textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                    hintText: 'Not counted',
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                key: const Key('stockIncrease'),
                onPressed: atMax ? null : () => _step(1),
                icon: const Icon(Icons.add),
                tooltip: 'One more',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Count the units on the shelf',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (wasCounted) ...[
                Expanded(
                  child: TextButton.icon(
                    key: const Key('stockClear'),
                    onPressed: _clear,
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Not counted'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  key: const Key('stockSave'),
                  // Disabled until there is a number, because committing an empty
                  // field as zero is exactly the mistake described on [_typed].
                  onPressed: _typed == null ? null : _save,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.brandGreenSurface,
                    foregroundColor: AppColors.brandGreen,
                    side: const BorderSide(
                      color: AppColors.brandGreenSurfaceBorder,
                    ),
                  ),
                  child: const Text('Save count'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
