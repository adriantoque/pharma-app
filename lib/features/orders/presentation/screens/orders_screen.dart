import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/models/order_history_model.dart';
import '../../data/repositories/firestore_order_history_repository.dart';
import '../../data/repositories/order_history_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../widgets/order_tabs.dart';
import '../widgets/order_card.dart';

/// Orders tab: shows order history with tabs for All, New, and Approved.
///
/// Matches the Orders.html design with tabs for filtering orders by status.
///
/// Accepts an optional [historyFactory] seam so tests can inject a fake
/// repository rather than reaching for Firestore.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key, this.historyFactory});

  /// Builds the [OrderHistoryRepository] the screen reads from.
  ///
  /// If not provided, a [FirestoreOrderHistoryRepository] scoped to the signed-in
  /// user is used.
  final OrderHistoryRepository Function()? historyFactory;

  @override
  Widget build(BuildContext context) {
    final factory = historyFactory ??
        () => FirestoreOrderHistoryRepository(
          firestore: context.read<FirebaseFirestore>(),
          uid: context.read<AuthProvider>().user?.id ?? '',
        );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<OrdersProvider>(
          create: (context) => OrdersProvider(historyFactory: factory)
            ..initialize(),
        ),
      ],
      child: const _OrdersView(),
    );
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders'), centerTitle: true),
      body: Consumer<OrdersProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allOrders = provider.orders;
          final newOrders = allOrders
              .where((o) => o.status == OrderStatus.new_)
              .toList();
          final approvedOrders = allOrders
              .where((o) => o.status == OrderStatus.approved)
              .toList();

          return Column(
            children: [
              // Tabs
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: OrderTabs(
                  selectedTab: provider.currentTab,
                  onTabChanged: provider.setTab,
                  allCount: allOrders.length,
                  newCount: newOrders.length,
                  approvedCount: approvedOrders.length,
                ),
              ),
              // Order list
              Expanded(
                child: _buildOrderList(
                  context,
                  provider.currentTab,
                  allOrders,
                  newOrders,
                  approvedOrders,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderList(
    BuildContext context,
    OrderTab tab,
    List<OrderHistory> allOrders,
    List<OrderHistory> newOrders,
    List<OrderHistory> approvedOrders,
  ) {
    final provider = context.read<OrdersProvider>();
    final orders = switch (tab) {
      OrderTab.all => allOrders,
      OrderTab.new_ => newOrders,
      OrderTab.approved => approvedOrders,
    };

    if (orders.isEmpty) {
      return _EmptyOrderView(tab: tab);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        final canApprove = order.status == OrderStatus.new_;
        return OrderCard(
          order: order,
          onApprove: canApprove ? () => provider.approveOrder(order.id) : null,
        );
      },
    );
  }
}

class _EmptyOrderView extends StatelessWidget {
  const _EmptyOrderView({required this.tab});

  final OrderTab tab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (tab) {
      OrderTab.all => 'all',
      OrderTab.new_ => 'new',
      OrderTab.approved => 'approved',
    };

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
              'No $label orders right now.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
