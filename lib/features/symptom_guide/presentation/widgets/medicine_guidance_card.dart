import 'package:flutter/material.dart';

import '../../../search/data/models/medicine_model.dart' show StockState;

/// A card showing one medicine's guidance.
///
/// The caller provides the pre-resolved text so the widget does not need to
/// import [MedicineModel] or [MedicineGuidance]; only the [StockState] enum is
/// shared, so the stock line can be coloured the same way the search and scan
/// rows colour theirs.
class MedicineGuidanceCard extends StatelessWidget {
  const MedicineGuidanceCard({
    super.key,
    required this.recommendedName,
    required this.howToUse,
    required this.cautions,
    required this.formattedPrice,
    required this.stockText,
    required this.stockState,
    required this.onAdd,
  });

  /// The medicine name shown as the header.
  final String recommendedName;

  /// Plain-language directions: how it is taken, with what, and anything that
  /// changes how it works (e.g. "after food").
  final String howToUse;

  /// Warnings and red flags: who should not take it, and when to stop and ask
  /// the pharmacist.
  final String cautions;

  /// The price as it appears on the price list, e.g. "₱180.00".
  final String formattedPrice;

  /// Stock status text, e.g. "5 in stock" or "Out of stock".
  final String stockText;

  /// The state behind [stockText], so the label is coloured to match and an
  /// out-of-stock line cannot offer an add button.
  final StockState stockState;

  /// Called when the user taps "Add to order". Not called while the line is out
  /// of stock.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medicine name header
            Text(
              recommendedName,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            // Price / stock line
            Row(
              children: [
                Text(
                  formattedPrice,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: 6),
                Text(
                  stockText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    // Matched to the search and scan rows: a shortage is called
                    // out, an uncounted item is merely muted.
                    color: switch (stockState) {
                      StockState.outOfStock ||
                      StockState.low => theme.colorScheme.error,
                      StockState.unknown => theme.colorScheme.outline,
                      StockState.available =>
                        theme.colorScheme.onSurfaceVariant,
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Guidance / how-to-use
            Text(
              howToUse,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              cautions,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),

            // Add to order. Disabled only when the shelf is empty; the
            // confirmation snackbar belongs to the screen, not the card, so
            // there is one place that owns what "added" means.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: Key('add$recommendedName'),
                onPressed: stockState == StockState.outOfStock ? null : onAdd,
                child: const Text('Add to order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
