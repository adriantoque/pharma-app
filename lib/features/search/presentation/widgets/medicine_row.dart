import 'package:flutter/material.dart';

import '../../data/models/medicine_model.dart';

/// A search/result row showing a medicine with add/remove quantity control.
///
/// DashboardScreen owns the search UI; these widgets are split out of it for legibility.
class MedicineRow extends StatelessWidget {
  const MedicineRow({
    super.key,
    required this.medicine,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final MedicineModel medicine;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (stockLabel, stockState) = medicine.stockLine;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  medicine.name,
                  maxLines: 2,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  stockLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: switch (stockState) {
                      StockState.outOfStock || StockState.low =>
                        theme.colorScheme.error,
                      StockState.unknown => theme.colorScheme.outline,
                      StockState.available => theme.colorScheme.onSurfaceVariant,
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            medicine.formattedPrice,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          _QuantityControl(
            medicine: medicine,
            quantity: quantity,
            onAdd: onAdd,
            onRemove: onRemove,
          ),
        ],
      ),
    );
  }
}

/// The trailing control on a search row: add button or quantity badge.
class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.medicine,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final MedicineModel medicine;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (quantity == 0) {
      return IconButton.filledTonal(
        onPressed: medicine.isOutOfStock ? null : onAdd,
        icon: const Icon(Icons.add),
        tooltip: 'Add ${medicine.name}',
      );
    }

    return Tooltip(
      message: 'Remove $quantity × ${medicine.name}',
      child: FilledButton.tonal(
        onPressed: onRemove,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 40),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.remove, size: 18),
            const SizedBox(width: 4),
            Text('×$quantity'),
          ],
        ),
      ),
    );
  }
}

/// Shows when the catalogue could not be read at all.
class CatalogueError extends StatelessWidget {
  const CatalogueError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'The price list did not load',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Dismiss'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows when a search query returns no results.
class NoResults extends StatelessWidget {
  const NoResults({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No match for "$query"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item count label shown below the search field.
class ResultsCount extends StatelessWidget {
  const ResultsCount({
    super.key,
    required this.resultsCount,
    required this.totalCount,
    required this.query,
    this.isLoading = false,
  });

  final int resultsCount;
  final int totalCount;
  final String query;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = isLoading
        ? 'Loading the price list...'
        : query.isEmpty
            ? '$totalCount items'
            : '$resultsCount of $totalCount items';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Search text field with clear button.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hintText = 'Search name or price',
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        autofocus: autofocus,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear',
                  onPressed: onClear,
                ),
        ),
      ),
    );
  }
}