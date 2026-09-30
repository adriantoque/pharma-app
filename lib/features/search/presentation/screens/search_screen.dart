import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/medicine_model.dart';
import '../../data/repositories/medicine_repository.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../widgets/quantity_sheet.dart';

/// Search tab: looks a medicine up in the pharmacy price list.
///
/// Filtering happens against [MedicineRepository] rather than inside the widget,
/// so swapping the static list for Firestore later touches no UI code.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.repository = const StaticMedicineRepository()});

  final MedicineRepository repository;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MedicineModel> _results = const [];

  @override
  void initState() {
    super.initState();
    _results = widget.repository.all();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() => _results = widget.repository.search(query));
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
    final total = widget.repository.all().length;
    final query = _controller.text.trim();

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
                query.isEmpty
                    ? '$total items'
                    : '${_results.length} of $total items',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? _NoResults(query: query)
                : ListView.separated(
                    controller: _scrollController,
                    itemCount: _results.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final medicine = _results[index];
                      // Watched, not read: the row's control is driven by the
                      // quantity, so it has to rebuild when the order changes.
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
          ),
        ],
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
