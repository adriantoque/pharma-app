import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/order_line_model.dart';
import '../providers/order_provider.dart';

/// Orders tab: the order being built, as added from the Search tab.
///
/// Reads the same [OrderProvider] the search rows write to, so a change made
/// here is reflected in the search list's quantities when the user goes back.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrderProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Orders'), centerTitle: true),
      body: order.isEmpty
          ? const _EmptyOrder()
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: order.lines.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) =>
                        _OrderLineTile(line: order.lines[index]),
                  ),
                ),
                _OrderSummary(order: order),
                _OrderActionsBar(onPressed: () => _showReceiptDialog(context, order)),
              ],
            ),
    );
  }

  void _showReceiptDialog(BuildContext context, OrderProvider order) {
    showDialog(
      context: context,
      builder: (context) => _ReceiptPreviewDialog(order: order),
    );
  }
}

class _EmptyOrder extends StatelessWidget {
  const _EmptyOrder();

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
              Icons.shopping_basket_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing in this order yet',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Find an item in Search and tap the + to add it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of the order, with the quantity adjustable in place.
///
/// The quantity lives here as well as in the add sheet because Search's row
/// control switches to a remove as soon as an item is in the order, so this is
/// the only place the amount of an already-added item can be changed.
class _OrderLineTile extends StatelessWidget {
  const _OrderLineTile({required this.line});

  final OrderLineModel line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = context.read<OrderProvider>();
    final medicine = line.medicine;
    // The shelf is the real limit; [OrderProvider.maxQuantity] is only the
    // backstop for an item holding more than 99.
    final atMax = line.quantity >= OrderProvider.capFor(medicine);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medicine.name, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 2),
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
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => order.setQuantity(medicine, line.quantity - 1),
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'One fewer ${medicine.name}',
          ),
          SizedBox(
            // Wide enough for two digits at bodyLarge, so 99 does not reflow the
            // row as the count grows.
            width: 28,
            child: Text(
              '${line.quantity}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          IconButton(
            // Disabled at the cap rather than silently doing nothing.
            onPressed: atMax
                ? null
                : () => order.setQuantity(medicine, line.quantity + 1),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'One more ${medicine.name}',
          ),
          IconButton(
            onPressed: () => order.remove(medicine),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove ${medicine.name}',
          ),
        ],
      ),
    );
  }
}

/// Sticky item count and total, pinned above the navigation bar.
class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});

  final OrderProvider order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              order.itemCount == 1 ? '1 item' : '${order.itemCount} items',
              // Keyed because the count and the total legitimately equal a line's
              // own figures whenever the order holds a single item, so a test
              // cannot tell them apart by text alone.
              key: const Key('orderItemCount'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text('Total', style: theme.textTheme.titleMedium),
          const SizedBox(width: 12),
          Text(
            order.formattedTotal,
            key: const Key('orderTotal'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width anchored action bar with the Create Receipt button.
/// Placed below the order summary; SafeArea ensures it sits above the system
/// nav bar and leaves room for snackbars (which overlay via ScaffoldMessenger).
class _OrderActionsBar extends StatelessWidget {
  const _OrderActionsBar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: FilledButton.icon(
        key: const Key('createReceiptButton'),
        onPressed: onPressed,
        icon: const Icon(Icons.receipt_long),
        label: const Text('Create Receipt'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Dialog previewing the receipt before clearing the order.
class _ReceiptPreviewDialog extends StatelessWidget {
  const _ReceiptPreviewDialog({required this.order});

  final OrderProvider order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Create Receipt'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review the order and confirm to create the receipt.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: order.lines.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 8),
                itemBuilder: (context, index) {
                  final line = order.lines[index];
                  return _ReceiptLineItem(line: line);
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      order.itemCount == 1 ? '1 item' : '${order.itemCount} items',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    'Total',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    order.formattedTotal,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            order.clear();
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Receipt created. Order cleared.')),
            );
          },
          child: const Text('Create Receipt'),
        ),
      ],
    );
  }
}

class _ReceiptLineItem extends StatelessWidget {
  const _ReceiptLineItem({required this.line});

  final OrderLineModel line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medicine = line.medicine;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(medicine.name, style: theme.textTheme.bodyMedium),
              Text(
                '${line.quantity} × ${medicine.formattedPrice}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          line.formattedTotal,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
