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
              // Complete the order first
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogue = context.watch<MedicineProvider>();
    final order = context.watch<OrderProvider>();
    final all = catalogue.all();
    final query = _query.trim();
    final results = catalogue.search(query);

    final isLoading = catalogue.isLoading;
    final error = catalogue.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        centerTitle: true,
        actions: [
          // The cart lives in the app bar rather than as a fixed panel at the
          // bottom: the panel ate half the screen and left the product list
          // fighting it for height. The badge is what tells the pharmacist
          // there is anything to check out at all, so the icon is hidden while
          // the order is empty.
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
          // Search bar
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
          // Products header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Products', style: theme.textTheme.titleMedium),
            ),
          ),
          // Product list - takes all remaining space
          Expanded(
            child: switch ((error, isLoading)) {
              (final String message, _) => CatalogueError(
                message: message,
                onRetry: () => catalogue.clearError(),
              ),
              (_, true) => const Center(child: CircularProgressIndicator()),
              (_, false) =>
                query.isEmpty
                    ? _allProductsList(all, order)
                    : _resultsColumn(
                        query: query,
                        results: results,
                        total: all.length,
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
        final quantity = order.quantityOf(medicine);

        return MedicineRow(
          medicine: medicine,
          quantity: quantity,
          onAdd: () => order.add(medicine, 1),
          onRemove: () => order.remove(medicine),
        );
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
    return Column(
      children: [
        ResultsCount(
          resultsCount: results.length,
          totalCount: total,
          query: query,
          isLoading: isLoading,
        ),
        Expanded(
          child: results.isEmpty
              ? NoResults(query: query)
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: results.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final medicine = results[index];
                    final quantity = order.quantityOf(medicine);

                    return MedicineRow(
                      medicine: medicine,
                      quantity: quantity,
                      onAdd: () => order.add(medicine, 1),
                      onRemove: () => order.remove(medicine),
                    );
                  },
                ),
        ),
      ],
    );
  }
}