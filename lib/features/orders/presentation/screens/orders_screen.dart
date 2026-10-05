import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/currency.dart';
import '../../data/models/order_history_model.dart';
import '../../data/repositories/order_history_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/orders_provider.dart';

class OrdersScreen extends StatefulWidget {
  final OrderHistoryRepository Function()? historyFactory;

  const OrdersScreen({
    super.key,
    this.historyFactory,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The repository is built per signed-in user, so there is no single instance
    // to hand over from a provider -- the app registers the factory that decides
    // where a user's history lives and this is the call that resolves it. Reading
    // a bare OrderHistoryRepository here would throw at runtime, because nothing
    // registers one. `historyFactory` is the seam tests inject through.
    final historyFactory = widget.historyFactory ??
        () => context.read<OrderHistoryRepositoryFactory>()(
              context.read<AuthProvider>().user?.id ?? '',
            );
    final historyRepo = historyFactory();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'New'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: StreamBuilder<List<OrderHistory>>(
        stream: historyRepo.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: theme.colorScheme.error),
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

          final orders = snapshot.data ?? [];

          final newOrders =
              orders.where((o) => o.status == OrderStatus.new_).toList();
          final approvedOrders =
              orders.where((o) => o.status == OrderStatus.approved).toList();
          final rejectedOrders =
              orders.where((o) => o.status == OrderStatus.rejected).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _OrderListTab(
                orders: newOrders,
                emptyMessage: 'No pending new orders',
                emptyIcon: Icons.inbox_outlined,
                showActions: true,
              ),
              _OrderListTab(
                orders: approvedOrders,
                emptyMessage: 'No approved orders',
                emptyIcon: Icons.check_circle_outline,
                showActions: false,
              ),
              _OrderListTab(
                orders: rejectedOrders,
                emptyMessage: 'No rejected orders',
                emptyIcon: Icons.cancel_outlined,
                showActions: false,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderListTab extends StatelessWidget {
  final List<OrderHistory> orders;
  final String emptyMessage;
  final IconData emptyIcon;
  final bool showActions;

  const _OrderListTab({
    required this.orders,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.showActions,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderCard(
          order: order,
          showActions: showActions,
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderHistory order;
  final bool showActions;

  const _OrderCard({
    required this.order,
    required this.showActions,
  });

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
          backgroundColor: _getStatusColor(order.status, theme).withValues(alpha: 0.12),
          child: Icon(
            _getStatusIcon(order.status),
            color: _getStatusColor(order.status, theme),
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
            '${order.items.length} item(s) • ${_formatTimestamp(order.time)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCentavos(order.totalCentavos),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            _StatusBadge(status: order.status),
          ],
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
                // A Column, not a shrink-wrapped ListView: this list cannot scroll, so it has
                // no scroll position to speak of. As a Scrollable it looked for
                // one in the PageStorage bucket the ExpansionTile above it owns
                // and found that tile's expanded-or-not *bool* under the same
                // identifier, throwing a double cast -- which took the whole
                // expanded card down, actions included.
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
                if (showActions) ...[
                  const SizedBox(height: 16),
                  // Expanded rather than end-aligned natural widths: two icon buttons with labels
                  // are wider than the expanded card on a narrow phone, and an
                  // overflowing Row is an error, not just a clipped button.
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _updateStatus(context, OrderStatus.rejected),
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
                          onPressed: () => _updateStatus(context, OrderStatus.approved),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateStatus(BuildContext context, OrderStatus newStatus) {
    context.read<OrdersProvider>().updateOrderStatus(order.id, newStatus);
  }

  Color _getStatusColor(OrderStatus status, ThemeData theme) {
    return switch (status) {
      OrderStatus.approved => Colors.green.shade700,
      OrderStatus.rejected => theme.colorScheme.error,
      OrderStatus.new_ => theme.colorScheme.primary,
    };
  }

  IconData _getStatusIcon(OrderStatus status) {
    return switch (status) {
      OrderStatus.approved => Icons.check_circle_outline,
      OrderStatus.rejected => Icons.cancel_outlined,
      OrderStatus.new_ => Icons.pending_actions,
    };
  }

  String _formatTimestamp(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (backgroundColor, textColor, label) = switch (status) {
      OrderStatus.approved => (
          Colors.green.shade100,
          Colors.green.shade900,
          'APPROVED',
        ),
      OrderStatus.rejected => (
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer,
          'REJECTED',
        ),
      OrderStatus.new_ => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
          'NEW',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
