import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../orders/presentation/providers/order_provider.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../../../search/presentation/widgets/medicine_row.dart'
    show MedicineRow, CatalogueError, NoResults, ResultsCount, SearchField;
import '../../../search/presentation/widgets/quantity_sheet.dart';

/// Home tab: the counter dashboard.
///
/// Inline search is still the heart of the screen, so browsing (no query)
/// shows the day's figures and short-cuts, and typing a query replaces them
/// with the matching price-list rows. The scan and profile controls live in
/// the AppBar row instead of the old tiles, and expiring meds is part of the
/// "Need attention" section rather than a home tile of its own.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';

  /// How many attention items are shown before the "and N more" tail.
  static const int _attentionPreviewCount = 5;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() => _query = query);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _clearSearch() {
    _searchController.clear();
    _onQueryChanged('');
  }

  Future<void> _addItem(MedicineModel medicine) async {
    final order = context.read<OrderProvider>();
    final quantity = await showQuantitySheet(context, medicine: medicine);
    if (quantity == null) return;

    order.add(medicine, quantity);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $quantity × ${medicine.name}')),
    );
  }

  void _removeItem(MedicineModel medicine, int quantity) {
    final order = context.read<OrderProvider>();
    order.remove(medicine);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed $quantity × ${medicine.name}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => order.add(medicine, quantity),
        ),
      ),
    );
  }

  /// The result list shown while a query is in the field.
  Widget _resultsColumn({
    required String query,
    required List<MedicineModel> results,
    required int total,
    required bool isLoading,
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
          child: results.isEmpty ? NoResults(query: query) : _resultsList(results),
        ),
      ],
    );
  }

  Widget _resultsList(List<MedicineModel> results) {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: results.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final medicine = results[index];
        final quantity = context.watch<OrderProvider>().quantityOf(medicine);

        return MedicineRow(
          medicine: medicine,
          quantity: quantity,
          onAdd: () => _addItem(medicine),
          onRemove: () => _removeItem(medicine, quantity),
        );
      },
    );
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

    final expiredCount =
        all.where((m) => m.expiryDate != null && m.isExpired).length;
    final expiringSoonCount = all
        .where((m) =>
            m.expiryDate != null && !m.isExpired && m.daysUntilExpiry! <= 30)
        .length;
    final lowStock = all.where((m) => m.isLowStock).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Wilma Pharmacy's"),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications — coming soon')),
            ),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.pushNamed('home-profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search row: the field plus the scan short-cut on its right.
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
          Expanded(
            child: switch ((error, isLoading, query.isEmpty)) {
              (final String message, _, _) => CatalogueError(
                  message: message,
                  onRetry: () => catalogue.clearError(),
                ),
              (_, true, _) =>
                const Center(child: CircularProgressIndicator()),
              (_, _, true) => _browseList(
                  theme: theme,
                  order: order,
                  lowStock: lowStock,
                  expiringCount: expiredCount + expiringSoonCount,
                ),
              (_, _, false) => _resultsColumn(
                  query: query,
                  results: results,
                  total: all.length,
                  isLoading: isLoading,
                ),
            },
          ),
        ],
      ),
    );
  }

  /// The no-query counter view: today's figures, short-cuts and attention.
  Widget _browseList({
    required ThemeData theme,
    required OrderProvider order,
    required List<MedicineModel> lowStock,
    required int expiringCount,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _TodaySalesCard(itemCount: order.itemCount, total: order.formattedTotal),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _HomeActionButton(
                icon: Icons.point_of_sale_outlined,
                label: 'New Sale',
                onPressed: () => context.goNamed('new-sale'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HomeActionButton(
                icon: Icons.add_box_outlined,
                label: 'Add Product',
                onPressed: () => context.goNamed('inventory'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HomeActionButton(
                icon: Icons.assignment_return_outlined,
                label: 'Return',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Returns — coming soon')),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text('Need attention', style: theme.textTheme.titleMedium),
            ),
            TextButton(
              onPressed: () => context.goNamed('inventory'),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _AttentionChip(
              icon: Icons.event_busy_outlined,
              label: '$expiringCount expiring',
              onTap: () => context.pushNamed('home-expiring'),
            ),
            const SizedBox(width: 12),
            _AttentionChip(
              icon: Icons.inventory_2_outlined,
              label: '${lowStock.length} low',
              onTap: () => context.goNamed('inventory'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _AttentionCard(
          lowStock: lowStock.take(_attentionPreviewCount).toList(),
          moreCount: lowStock.length > _attentionPreviewCount
              ? lowStock.length - _attentionPreviewCount
              : 0,
        ),
      ],
    );
  }
}

/// The day at a glance: what the active order is worth, live.
class _TodaySalesCard extends StatelessWidget {
  const _TodaySalesCard({required this.itemCount, required this.total});

  final int itemCount;
  final String total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's sales",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              total,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              itemCount == 1 ? '1 item' : '$itemCount items',
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

/// A small pill showing one attention count; taps open the matching screen.
class _AttentionChip extends StatelessWidget {
  const _AttentionChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: StadiumBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the three equal-width short-cut buttons under the sales card.
class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The low-stock lines under "Need attention".
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.lowStock, required this.moreCount});

  final List<MedicineModel> lowStock;
  final int moreCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (lowStock.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Nothing is running low.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (var index = 0; index < lowStock.length; index++) ...[
              if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              _AttentionTile(medicine: lowStock[index]),
            ],
            if (moreCount > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    'and $moreCount more',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One low-stock line: the name and what the counter has left.
class _AttentionTile extends StatelessWidget {
  const _AttentionTile({required this.medicine});

  final MedicineModel medicine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, state) = medicine.stockLine;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              medicine.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: switch (state) {
                StockState.outOfStock || StockState.low =>
                  theme.colorScheme.error,
                StockState.unknown => theme.colorScheme.outline,
                StockState.available =>
                  theme.colorScheme.onSurfaceVariant,
              },
            ),
          ),
        ],
      ),
    );
  }
}