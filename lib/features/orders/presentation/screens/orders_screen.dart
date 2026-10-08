import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/currency.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/order_history_model.dart';
import '../../data/repositories/order_history_repository.dart';
import '../providers/orders_provider.dart';

/// The Orders tab: new orders waiting for a decision.
///
/// Only [OrderStatus.new_] orders appear here. Approving or rejecting one
/// moves it to [OrderHistoryScreen] -- the decision is recorded in the same
/// stream this screen reads, so the order disappears from the list the moment
/// the write lands, without a manual refresh.
///
/// Reached from the bottom nav. The AppBar's history icon opens the record of
/// what has already been decided.
class OrdersScreen extends StatelessWidget {
  final OrderHistoryRepository Function()? historyFactory;

  const OrdersScreen({
    super.key,
    this.historyFactory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final factory = historyFactory ??
        () => context.read<OrderHistoryRepositoryFactory>()(
              context.read<AuthProvider>().user?.id ?? '',
            );
    final historyRepo = factory();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order List'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Order history',
            icon: const Icon(Icons.history),
            onPressed: () => context.pushNamed('orders-history'),
          ),
        ],
      ),
      body: StreamBuilder<List<OrderHistory>>(
        stream: historyRepo.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text('Failed to load orders',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? const <OrderHistory>[];
          final pending = orders
              .where((o) => o.status == OrderStatus.new_)
              .toList()
            ..sort((a, b) => b.time.compareTo(a.time));

          if (pending.isEmpty) {
            return const _EmptyOrderList();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pending.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _PendingOrderCard(
              order: pending[index],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyOrderList extends StatelessWidget {
  const _EmptyOrderList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No pending orders',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New orders waiting for approval will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// One pending order, with the two buttons that move it out of the list.
class _PendingOrderCard extends StatelessWidget {
  const _PendingOrderCard({required this.order});

  final OrderHistory order;

  void _updateStatus(BuildContext context, OrderStatus newStatus) {
    context.read<OrdersProvider>().updateOrderStatus(order.id, newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        key: PageStorageKey(order.id),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: order.statusBackgroundColor,
          child: Icon(
            Icons.pending_actions,
            color: order.statusColor,
          ),
        ),
        title: Text(
          'Order #${order.id}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${order.items.length} item(s) · ${order.formattedDate(context: context)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: Text(
          formatCentavos(order.totalCentavos),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Line Items',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final line in order.items) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${line.quantity}x ${line.medicine.name}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          formatCentavos(line.totalCentavos),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _updateStatus(context, OrderStatus.rejected),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _updateStatus(context, OrderStatus.approved),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}