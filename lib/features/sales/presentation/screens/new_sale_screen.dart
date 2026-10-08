import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../orders/presentation/providers/order_provider.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../../../search/presentation/widgets/medicine_row.dart'
    show MedicineRow, CatalogueError, NoResults, ResultsCount, SearchField;
import '../../domain/payment_method.dart';
import 'cart_screen.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  PaymentMethod _paymentMethod = PaymentMethod.cashOnHand;

  /// Whether a medicine belongs on the New Sale shelf.
  ///
  /// Uncounced items are hidden: a count nobody has taken is not a count, and
  /// a sale screen is the wrong place to fix that -- the Inventory tab is.
  /// Out-of-stock items are kept so the counter can see the product exists and
  /// cannot be sold, which is what drives a reorder. They are drawn muted by
  /// [_saleRow], not removed.
  static bool _appearsOnSale(MedicineModel medicine) => medicine.stock != null;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showProceedDialog() {
    final order = context.read<OrderProvider>();
    final paymentLabel = _paymentMethod.label;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Sale'),
        content: Text('Complete this sale with $paymentLabel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              final success = order.complete();
              if (success) {
                context.go('/orders');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not complete sale. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  /// Opens the cart screen and applies whatever the user came back with.
  ///
  /// The payment method is returned even when Proceed was not tapped, so a
  /// user who changes it and then backs out still finds it selected the next
  /// time the cart is opened. Only `proceed: true` runs the confirmation.
  Future<void> _openCart() async {
    final result = await context.pushNamed<CartResult>(
      'new-sale-cart',
      extra: _paymentMethod,
    );

    if (!mounted || result == null) return;

    if (result.payment != _paymentMethod) {
      setState(() => _paymentMethod = result.payment);
    }

    if (result.proceed) _showProceedDialog();
  }

  void _onQueryChanged(String query) {
    setState(() => _query = query);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _clearSearch() {
    _searchController.clear();
    _onQueryChanged('');
  }

  /// One sale-row, muted when the item cannot be sold.
  ///
  /// The opacity is set here rather than inside [MedicineRow] so the shared
  /// widget keeps the same look it has on every other screen. 45% leaves the
  /// name and price readable while making it obvious the row is not buyable.
  Widget _saleRow(MedicineModel medicine, OrderProvider order) {
    final quantity = order.quantityOf(medicine);
    final row = MedicineRow(
      medicine: medicine,
      quantity: quantity,
      onAdd: () => order.add(medicine, 1),
      onRemove: () => order.remove(medicine),
    );
    return medicine.isOutOfStock ? Opacity(opacity: 0.45, child: row) : row;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogue = context.watch<MedicineProvider>();
    final order = context.watch<OrderProvider>();
    final all = catalogue.all();
    final query = _query.trim();
    final results = catalogue.search(query);

    // The rows the shelf shows: everything but the uncounted items. Used for
    // both the browse list and the search results, so a user typing "amox"
    // does not get a row the browse list would have hidden.
    final sellable = all.where(_appearsOnSale).toList(growable: false);

    final isLoading = catalogue.isLoading;
    final error = catalogue.error;

    return Scaffold(
      appBar: AppBar(
        // Explicit rather than `automaticallyImplyLeading`, because the sale
        // is reached with `goNamed` -- there is no back stack to imply a
        // leading arrow from. This is the one way out of the screen, and it
        // goes to Home, which is where the sale was started from.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to home',
          onPressed: () => context.goNamed('home'),
        ),
        title: const Text('New Sale'),
        centerTitle: true,
        actions: [
          if (order.isNotEmpty)
            IconButton(
              tooltip: 'View cart',
              icon: Badge.count(
                count: order.itemCount,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              onPressed: _openCart,
            ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SearchField(
                  controller: _searchController,
                  onChanged: _onQueryChanged,
                  onClear: _clearSearch,
                  hintText: 'Search medicines...',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton.filledTonal(
                  tooltip: 'Scan',
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  onPressed: () => context.pushNamed('home-scan'),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Products', style: theme.textTheme.titleMedium),
            ),
          ),
          Expanded(
            child: switch ((error, isLoading)) {
              (final String message, _) => CatalogueError(
                message: message,
                onRetry: () => catalogue.clearError(),
              ),
              (_, true) => const Center(child: CircularProgressIndicator()),
              (_, false) when sellable.isEmpty => const _NoCountedStock(),
              (_, false) =>
                query.isEmpty
                    ? _allProductsList(sellable, order)
                    : _resultsColumn(
                        query: query,
                        results: results,
                        total: sellable.length,
                        isLoading: isLoading,
                        order: order,
                      ),
            },
          ),
        ],
      ),
    );
  }

  Widget _allProductsList(List<MedicineModel> all, OrderProvider order) {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: all.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final medicine = all[index];
        return _saleRow(medicine, order);
      },
    );
  }

  Widget _resultsColumn({
    required String query,
    required List<MedicineModel> results,
    required int total,
    required bool isLoading,
    required OrderProvider order,
  }) {
    // The same rule as the browse list, applied to what the search matched.
    final visible = results.where(_appearsOnSale).toList(growable: false);

    return Column(
      children: [
        ResultsCount(
          resultsCount: visible.length,
          totalCount: total,
          query: query,
          isLoading: isLoading,
        ),
        Expanded(
          child: visible.isEmpty
              ? NoResults(query: query)
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: visible.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final medicine = visible[index];
                    return _saleRow(medicine, order);
                  },
                ),
        ),
      ],
    );
  }
}

/// Shown when every product on file is uncounted.
///
/// Reachable only on a freshly imported price list where nobody has taken a
/// count yet. Not an error: it is a to-do, and the button says where.
class _NoCountedStock extends StatelessWidget {
  const _NoCountedStock();

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
              Icons.inventory_2_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('No stock counted yet', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              'Count stock from the Inventory tab to begin a sale.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}