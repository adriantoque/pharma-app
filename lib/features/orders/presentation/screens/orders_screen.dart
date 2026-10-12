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
/// moves it out of this list, because the decision is written to the same
/// stream this screen reads. The history icon opens what has already been
/// decided.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  /// Created once per visit. Building the stream inside [build] would open a
  /// new listener on every rebuild and reset the list to a spinner each time.
  late final Stream<List<OrderHistory>> _orders;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().user?.id ?? '';
    _orders = context
        .read<OrderHistoryRepositoryFactory>()(uid)
        .watchAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
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
        stream: _orders,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // The raw error stays out of the UI: Firestore messages are for
            // developers. Log it so it can still be traced.
            debugPrint('Orders stream failed: ${snapshot.error}');
            return const _LoadError();
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pending = snapshot.data!
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

class _LoadError extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Orders could not be loaded',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Check the connection and try again later.',
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

class _EmptyOrderList extends StatelessWidget {
  const _EmptyOrderList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No orders waiting',
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

  /// Units across every line, which is what the counter means by "items".
  int get _units => order.items.fold(0, (sum, line) => sum + line.quantity);

  Future<void> _approve(BuildContext context) async {
    await context
        .read<OrdersProvider>()
        .updateOrderStatus(order.id, OrderStatus.approved);
  }

  Future<void> _reject(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject this order?'),
        content: Text('Order #${order.id} will be removed from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await context
        .read<OrdersProvider>()
        .updateOrderStatus(order.id, OrderStatus.rejected);
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
          child: Icon(Icons.pending_actions, color: order.statusColor),
        ),
        title: Text(
          'Order #${order.id}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$_units ${_units == 1 ? 'item' : 'items'} · '
            '${order.formattedDate(context: context)}',
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order lines',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final line in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _reject(context),
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
                        onPressed: () => _approve(context),
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
