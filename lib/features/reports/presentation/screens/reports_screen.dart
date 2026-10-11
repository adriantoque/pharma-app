import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reports_provider.dart';
import '../../data/models/report_range.dart';
import '../../data/models/sales_report.dart';
import '../../data/models/stock_alert.dart';
import '../../data/models/expiry_alert.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onRangeChanged(Set<ReportRange> selection) {
    if (selection.isEmpty) return;
    context.read<ReportsProvider>().setRange(selection.first);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sales Summary'),
            Tab(text: 'Low Stock Alerts'),
            Tab(text: 'Expiring Items'),
          ],
        ),
      ),
      body: Consumer<ReportsProvider>(
        builder: (context, provider, child) {
          final initialLoading =
              !provider.hasLoadedOnce && provider.isLoading;

          if (initialLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Time Range Selector
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: SegmentedButton<ReportRange>(
                  segments: const [
                    ButtonSegment(
                      value: ReportRange.today,
                      label: Text('Daily'),
                      icon: Icon(Icons.today),
                    ),
                    ButtonSegment(
                      value: ReportRange.week,
                      label: Text('Weekly'),
                      icon: Icon(Icons.calendar_view_week),
                    ),
                    ButtonSegment(
                      value: ReportRange.month,
                      label: Text('Monthly'),
                      icon: Icon(Icons.calendar_month),
                    ),
                  ],
                  selected: {provider.range},
                  onSelectionChanged: _onRangeChanged,
                ),
              ),

              // Expanded Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _SalesReportView(
                      report: provider.salesReport,
                      error: provider.salesError,
                      isLoading: provider.isSalesLoading,
                      onRetry: () => provider.retry(ReportSource.sales),
                    ),
                    _LowStockAlertsView(
                      alerts: provider.lowStockAlerts,
                      error: provider.stockError,
                      isLoading: provider.isStockLoading,
                      onRetry: () => provider.retry(ReportSource.stock),
                    ),
                    _ExpiryAlertsView(
                      alerts: provider.expiryAlerts,
                      error: provider.expiryError,
                      isLoading: provider.isExpiryLoading,
                      onRetry: () => provider.retry(ReportSource.expiry),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const _ReportEmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ReportErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportLoadingState extends StatelessWidget {
  final String message;

  const _ReportLoadingState({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. Sales Summary View
// ==========================================
class _SalesReportView extends StatelessWidget {
  final SalesReport? report;
  final String? error;
  final bool isLoading;
  final VoidCallback onRetry;

  const _SalesReportView({
    required this.report,
    required this.error,
    required this.isLoading,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _ReportLoadingState(message: 'Loading sales report...');
    }

    if (error != null) {
      return _ReportErrorState(message: error!, onRetry: onRetry);
    }

    final r = report;
    if (r == null) {
      return const _ReportEmptyState(
        message: 'No sales data available.',
        icon: Icons.analytics_outlined,
      );
    }

    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      children: [
        // Metric Cards Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWide ? 1.8 : 1.4,
              children: [
                _MetricCard(
                  title: 'Total Sales',
                  value: r.formattedTotalRevenue,
                  icon: Icons.payments_outlined,
                  color: theme.colorScheme.primary,
                ),
                _MetricCard(
                  title: 'Orders',
                  value: r.totalOrders.toString(),
                  icon: Icons.receipt_long_outlined,
                  color: theme.colorScheme.secondary,
                ),
                _MetricCard(
                  title: 'Average Order',
                  value: r.formattedAverageBill,
                  icon: Icons.analytics_outlined,
                  color: theme.colorScheme.tertiary,
                ),
                _MetricCard(
                  title: 'Est. Profit',
                  value: r.formattedProfit,
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        Text('Sales Breakdown', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: r.categorySales.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final category = r.categorySales[index];
              return ListTile(
                title: Text(category.category),
                subtitle: Text('Revenue share: ${category.percentage}%'),
                trailing: Text(
                  category.formattedRevenue,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. Low Stock Alerts View
// ==========================================
class _LowStockAlertsView extends StatelessWidget {
  final List<StockAlert> alerts;
  final String? error;
  final bool isLoading;
  final VoidCallback onRetry;

  const _LowStockAlertsView({
    required this.alerts,
    required this.error,
    required this.isLoading,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _ReportLoadingState(message: 'Loading stock alerts...');
    }

    if (error != null) {
      return _ReportErrorState(message: error!, onRetry: onRetry);
    }

    if (alerts.isEmpty) {
      return const _ReportEmptyState(
        message: 'All stock levels are optimal.',
        icon: Icons.inventory_2_outlined,
      );
    }

    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: alerts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final alert = alerts[index];
        final isOutOfStock = alert.currentStock == 0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: isOutOfStock
                  ? theme.colorScheme.error
                  : Colors.amber.shade700,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isOutOfStock
                  ? theme.colorScheme.errorContainer
                  : Colors.amber.shade100,
              child: Icon(
                isOutOfStock ? Icons.warning_amber : Icons.inventory_2_outlined,
                color: isOutOfStock
                    ? theme.colorScheme.onErrorContainer
                    : Colors.amber.shade900,
              ),
            ),
            title: Text(alert.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Threshold: ${alert.reorderLevel}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isOutOfStock ? 'Out of Stock' : '${alert.currentStock} remaining',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOutOfStock ? theme.colorScheme.error : Colors.amber.shade900,
                  ),
                ),
                Text('Current stock', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// 3. Expiry Alerts View
// ==========================================
class _ExpiryAlertsView extends StatelessWidget {
  final List<ExpiryAlert> alerts;
  final String? error;
  final bool isLoading;
  final VoidCallback onRetry;

  const _ExpiryAlertsView({
    required this.alerts,
    required this.error,
    required this.isLoading,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _ReportLoadingState(message: 'Loading expiry alerts...');
    }

    if (error != null) {
      return _ReportErrorState(message: error!, onRetry: onRetry);
    }

    if (alerts.isEmpty) {
      return const _ReportEmptyState(
        message: 'No expiring items detected.',
        icon: Icons.event_busy,
      );
    }

    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: alerts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final alert = alerts[index];
        final isExpired = alert.isExpired;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: isExpired ? theme.colorScheme.error : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: Icon(
              Icons.event_busy,
              color: isExpired ? theme.colorScheme.error : theme.colorScheme.primary,
            ),
            title: Text(alert.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Expiry Date: ${alert.expiryDate}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isExpired
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isExpired ? 'Expired' : 'Check date',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isExpired
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}