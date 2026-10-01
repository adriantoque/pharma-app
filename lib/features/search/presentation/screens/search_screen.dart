import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/medicine_model.dart';
import '../../data/repositories/medicine_repository.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../providers/medicine_provider.dart';
import '../widgets/quantity_sheet.dart';

/// Search tab: looks a medicine up in the pharmacy price list.
///
/// Reads the catalogue from [MedicineProvider] and keeps only the query here, so
/// the filtering rule stays on the model and the list stays on the provider: a
/// filter held in the widget would have to be re-applied on every catalogue
/// change to stay correct.
///
/// [repository] exists for tests, which inject a static list. It is read once, on
/// first build, and ignored afterwards: swapping it mid-session would be a
/// different catalogue from the one the order screen is holding.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.repository = const StaticMedicineRepository()});

  final MedicineRepository repository;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// The catalogue used when the widget is given one directly, as tests do.
  ///
  /// Null on the real app, where [MedicineProvider] is the source.
  MedicineRepository? _static;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _static ??= widget.repository;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() => _query = query);
    // Without this the list keeps its old offset, so clearing a search would
    // strand the user part-way down the alphabet instead of at the top.
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _clear() {
    _controller.clear();
    _onQueryChanged('');
  }

  /// Asks for a quantity and adds the item to the order.
  ///
  /// Only reachable while the item is not in the order: once it is, the row's
  /// control removes it instead, and the amount is edited from the order itself.
  /// That is why the sheet does not need to prefill a quantity.
  Future<void> _addItem(MedicineModel medicine) async {
    final order = context.read<OrderProvider>();
    final quantity = await showQuantitySheet(context, medicine: medicine);
    // Null means the sheet was dismissed, which is not the same as adding zero.
    if (quantity == null) return;

    order.add(medicine, quantity);

    // After the await, so the confirmation is not swallowed by the sheet that is
    // still on its way off screen.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $quantity × ${medicine.name}')),
    );
  }

  /// Takes every unit of [medicine] back out, offering an undo.
  ///
  /// Removal is one tap on the row's control, and a mis-tap at a busy counter
  /// would otherwise cost the sale, so the snackbar that reports it carries the
  /// way back.
  void _removeItem(MedicineModel medicine, int quantity) {
    final order = context.read<OrderProvider>();
    order.remove(medicine);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed $quantity × ${medicine.name}'),
        action: SnackBarAction(
          label: 'Undo',
          // The line is gone by now, so this re-adds rather than restoring it.
          onPressed: () => order.add(medicine, quantity),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final static = _static;

    // Watched, not read: a stock count typed on the inventory screen and the
    // first read of the catalogue both have to repaint this list.
    final live = static == null ? context.watch<MedicineProvider>() : null;

    final results = static?.search(_query) ?? live!.search(_query);
    final total = static?.all().length ?? live!.all().length;
    final isLoading = live?.isLoading ?? false;
    final error = live?.error;
    final query = _query.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Search'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Search name or price',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear',
                        onPressed: _clear,
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                // Suppressed while the catalogue is still loading, because
                // "0 items" is a statement about the pharmacy and the truth is
                // that nobody has asked yet.
                isLoading
                    ? 'Loading the price list...'
                    : query.isEmpty
                        ? '$total items'
                        : '${results.length} of $total items',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: switch ((error, isLoading)) {
              (final String message, _) => _CatalogueError(
                message: message,
                onRetry: () => live?.clearError(),
              ),
              (_, true) => const Center(
                child: CircularProgressIndicator(),
              ),
              _ =>
                results.isEmpty
                    ? _NoResults(query: query)
                    : ListView.separated(
                        controller: _scrollController,
                        itemCount: results.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final medicine = results[index];
                          // Watched, not read: the row's control is driven by
                          // the quantity, so it has to rebuild when the order
                          // changes.
                          final quantity = context
                              .watch<OrderProvider>()
                              .quantityOf(medicine);

                          return _MedicineRow(
                            medicine: medicine,
                            quantity: quantity,
                            onAdd: () => _addItem(medicine),
                            onRemove: () => _removeItem(medicine, quantity),
                          );
                        },
                      ),
            },
          ),
        ],
      ),
    );
  }
}

/// Shown when the catalogue could not be read at all.
///
/// A whole screen that says so, rather than an empty list: an empty price list
/// is indistinguishable from a pharmacy that stocks nothing, and the first thing
/// anyone would do about that is start deleting products.
class _CatalogueError extends StatelessWidget {
  const _CatalogueError({required this.message, this.onRetry});

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

class _MedicineRow extends StatelessWidget {
  const _MedicineRow({
    required this.medicine,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final MedicineModel medicine;

  /// How many are already in the order, which is what decides whether the
  /// control offers an add or a remove.
  final int quantity;

  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Label and state come back together from the model so a healthy count can
    // never be rendered in the error colour, or the other way round.
    final (stockLabel, stockState) = medicine.stockLine;

    return Padding(
      // Tighter than the single-line row it replaced: the stock line adds
      // height, and 64 rows is a long scroll to give away padding to.
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
                  // Two lines, so a long name wraps instead of being cut off --
                  // an ellipsised drug name is not something to hand a counter
                  // -- while still bounding the row height so the list keeps an
                  // even rhythm. Two of the 64 names need the second line at
                  // 360dp.
                  maxLines: 2,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  stockLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    // An uncounted item is muted rather than flagged: nothing is
                    // wrong, the number is simply missing, and colouring it like
                    // a shortage would cry wolf across a whole imported list.
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

/// The trailing control on a search row.
///
/// One control in one place rather than an add button plus a separate badge:
/// two controls on a 360dp row leaves too little width for a long drug name, and
/// the quantity has to be visible anyway for the user to know what they have
/// already added.
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
      // An out-of-stock item keeps the button, greyed out, rather than losing it:
      // the item is still a real line in the price list, and a row that silently
      // ends short of a control reads as a layout bug rather than "none left".
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
          // The defaults are sized for a text button, which pushes a long name
          // into an ellipsis on the narrowest phone the app supports.
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

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

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
