import 'package:flutter/material.dart';

/// A card showing one medicine's guidance.
///
/// The caller provides the pre-resolved text so the widget does not need to
/// import [MedicineModel] or [MedicineGuidance].
class MedicineGuidanceCard extends StatelessWidget {
  const MedicineGuidanceCard({
    super.key,
    required this.recommendedName,
    required this.howToUse,
    required this.cautions,
    required this.formattedPrice,
    required this.stockText,
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

  /// Called when the user taps "Add to order".
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
                    color: theme.colorScheme.onSurfaceVariant,
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

            // Add to order — visible when we have data and not a draft-only
            // (draft entries are in the placeholder phase).
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  onAdd();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to order')),
                  );
                },
                child: const Text('Add to order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}