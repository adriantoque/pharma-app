import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../orders/data/models/order_line_model.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../../../search/presentation/widgets/medicine_row.dart'
    show MedicineRow, CatalogueError, NoResults, ResultsCount, SearchField;

enum PaymentMethod { cashOnHand, gcash }

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
    final itemCount = order.itemCount;
    final paymentLabel = _paymentMethod == PaymentMethod.cashOnHand ? 'Cash on Hand' : 'GCash';

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
              child: Text(
                'Products',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          // Product list - takes remaining space
          Expanded(
            child: switch ((error, isLoading)) {
              (final String message, _) => CatalogueError(
                  message: message,
                  onRetry: () => catalogue.clearError(),
                ),
              (_, true) => const Center(child: CircularProgressIndicator()),
              (_, false) => query.isEmpty
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
          // Cart section - fixed height bottom panel when items exist
          if (order.isNotEmpty)
            _CartSection(
              order: order,
              selectedPayment: _paymentMethod,
              onPaymentChanged: (v) => setState(() => _paymentMethod = v),
              onProceed: _showProceedDialog,
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

class _CartSection extends StatelessWidget {
  const _CartSection({
    required this.order,
    required this.selectedPayment,
    required this.onPaymentChanged,
    required this.onProceed,
  });

  final OrderProvider order;
  final PaymentMethod selectedPayment;
  final ValueChanged<PaymentMethod> onPaymentChanged;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
final theme = Theme.of(context);
    final lines = order.lines;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
      child: SingleChildScrollView(
        key: const Key('cartScrollView'),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cart', style: theme.textTheme.titleSmall),
              const Divider(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.15,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: lines.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 12, endIndent: 12),
                  itemBuilder: (context, index) =>
                      _CartItemTile(line: lines[index], compact: true),
                ),
              ),
              const Divider(height: 12),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '${order.itemCount} items',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text('Total', style: theme.textTheme.titleSmall),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      order.formattedTotal,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 12),
              _PaymentMethodSelector(
                selectedPayment: selectedPayment,
                onChanged: onPaymentChanged,
              ),
              const Divider(height: 12),
              SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('proceedButton'),
                    onPressed: onProceed,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Proceed'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.line, this.compact = false});

  final OrderLineModel line;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = context.read<OrderProvider>();
    final medicine = line.medicine;
    final atMax = line.quantity >= OrderProvider.capFor(medicine);

    final hPadding = compact ? 12.0 : 16.0;
    final vPadding = compact ? 6.0 : 8.0;
    final nameStyle = compact ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge;
    final qtyStyle = compact ? theme.textTheme.bodySmall : theme.textTheme.bodyLarge;
    final totalStyle = compact 
        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary)
        : theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary);
    final iconSize = compact ? 20.0 : 24.0;
    final qtyWidth = compact ? 24.0 : 28.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPadding, vPadding, hPadding / 2, vPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(medicine.name, style: nameStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (!compact) const SizedBox(height: 2),
                if (!compact)
                  Text(
                    line.formattedQuantity,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            line.formattedTotal,
            style: totalStyle,
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => order.setQuantity(medicine, line.quantity - 1),
            icon: Icon(Icons.remove_circle_outline, size: iconSize),
            tooltip: 'One fewer ${medicine.name}',
            constraints: BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          SizedBox(
            width: qtyWidth,
            child: Text(
              '${line.quantity}',
              textAlign: TextAlign.center,
              style: qtyStyle,
            ),
          ),
          IconButton(
            onPressed: atMax
                ? null
                : () => order.setQuantity(medicine, line.quantity + 1),
            icon: Icon(Icons.add_circle_outline, size: iconSize),
            tooltip: 'One more ${medicine.name}',
            constraints: BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            onPressed: () => order.remove(medicine),
            icon: Icon(Icons.delete_outline, size: iconSize),
            tooltip: 'Remove ${medicine.name}',
            constraints: BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selectedPayment,
    required this.onChanged,
  });

  final PaymentMethod selectedPayment;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Payment Method', style: theme.textTheme.labelSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _PaymentMethodTile(
              key: const Key('paymentCashOnHand'),
              label: 'Cash on Hand',
              value: PaymentMethod.cashOnHand,
              selectedPayment: selectedPayment,
              onChanged: onChanged,
            ),
            _PaymentMethodTile(
              key: const Key('paymentGCash'),
              label: 'GCash',
              subtitle: 'Coming soon',
              value: PaymentMethod.gcash,
              selectedPayment: selectedPayment,
              onChanged: onChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    super.key,
    required this.label,
    this.subtitle,
    required this.value,
    required this.selectedPayment,
    required this.onChanged,
  });

  final String label;
  final String? subtitle;
  final PaymentMethod value;
  final PaymentMethod selectedPayment;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = selectedPayment == value;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<PaymentMethod>(
              value: value,
              groupValue: selectedPayment,
              onChanged: (v) => onChanged(v!),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : null,
                )),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
