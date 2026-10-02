import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/reports_repository_impl.dart';
import '../../data/repositories/reports_repository.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../providers/reports_provider.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/tab_selector.dart';
import '../widgets/sales_hero_card.dart';
import '../widgets/daily_sales_chart.dart';
import '../widgets/best_sellers_list.dart';
import '../widgets/category_meters.dart';
import '../widgets/low_stock_list.dart';
import '../widgets/expiry_list.dart';

/// Reports tab: sales, stock and expiry at a glance.
///
/// Accepts an optional [repository] seam so that tests can inject data rather
/// than relying on the live repository.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, this.repository});

  /// The repository to use for loading report data.
  ///
  /// If not provided, [ReportsRepositoryImpl] with [MedicineProvider] is used.
  final ReportsRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repository =
        this.repository ??
        ReportsRepositoryImpl(
          medicineProvider: context.read<MedicineProvider>(),
        );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ReportsProvider>(
          create: (context) =>
              ReportsProvider(repository: repository)..initialize(),
        ),
      ],
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Export CSV (coming soon)',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export CSV — coming soon')),
            ),
          ),
          IconButton(
            tooltip: 'Custom date range (coming soon)',
            icon: const Icon(Icons.date_range_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Custom date range — coming soon')),
            ),
          ),
          IconButton(
            tooltip: 'Charts & visualizations (coming soon)',
            icon: const Icon(Icons.show_chart_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Charts — coming soon')),
            ),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
          ? _ErrorView(error: provider.error!, onRetry: provider.retry)
          : CustomScrollView(
              slivers: [
                // Range selector
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: DateRangeSelector(
                      selectedRange: provider.range,
                      onRangeChanged: provider.setRange,
                    ),
                  ),
                ),
                // Tab selector
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TabSelector(
                      selectedTab: provider.currentTab,
                      onTabChanged: provider.setTab,
                    ),
                  ),
                ),
                // Tab content
                SliverToBoxAdapter(child: _buildTabContent(context, provider)),
              ],
            ),
    );
  }

  Widget _buildTabContent(BuildContext context, ReportsProvider provider) {
    switch (provider.currentTab) {
      case ReportTab.sales:
        return _SalesTabContent(provider: provider);
      case ReportTab.lowStock:
        return _LowStockTabContent(provider: provider);
      case ReportTab.expiry:
        return _ExpiryTabContent(provider: provider);
    }
  }
}

class _SalesTabContent extends StatelessWidget {
  const _SalesTabContent({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    final report = provider.salesReport;

    if (report == null) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // Hero card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: SalesHeroCard(report: report, range: provider.range),
        ),
        // Daily sales chart
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: _ChartCard(
            title: 'Daily sales',
            child: DailySalesChart(report: report),
          ),
        ),
        // Best sellers and category meters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ChartCard(
                  title: 'Best sellers',
                  child: BestSellersList(report: report),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ChartCard(
                  title: 'Sales by category',
                  child: CategoryMeters(report: report),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _LowStockTabContent extends StatelessWidget {
  const _LowStockTabContent({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: _ChartCard(
          title: 'Reorder soon',
          child: LowStockList(alerts: provider.lowStockAlerts),
        ),
      ),
    );
  }
}

class _ExpiryTabContent extends StatelessWidget {
  const _ExpiryTabContent({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: _ChartCard(
          title: 'Expiring within 90 days',
          child: ExpiryList(alerts: provider.expiryAlerts),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

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
            Text('Failed to load reports', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
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
