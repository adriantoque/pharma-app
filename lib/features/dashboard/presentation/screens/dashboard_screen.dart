import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/currency.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../../../search/presentation/widgets/medicine_row.dart'
    show MedicineRow, CatalogueError, NoResults, ResultsCount, SearchField;
import '../../../search/presentation/widgets/quantity_sheet.dart';
import '../widgets/dashboard_tile.dart';

/// Home tab with inline search and quick-access tiles.
///
/// This screen is both the pharmacy's search box and its navigation hub,
/// because the bottom bar no longer has a Search destination.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogue = context.watch<MedicineProvider>();
    final all = catalogue.all();
    final results = catalogue.search(_query);
    final total = all.length;
    final isLoading = catalogue.isLoading;
    final error = catalogue.error;
    final query = _query.trim();

    final counted = all.where((m) => m.stock != null).toList();
    final countedCount = counted.length;
    final totalValue = counted.fold<int>(0, (sum, m) => sum + m.priceCentavos * m.stock!);
    final expiredCount = all.where((m) => m.expiryDate != null && m.isExpired).length;
    final expiringSoonCount = all.where((m) => m.expiryDate != null && !m.isExpired && m.daysUntilExpiry! <= 30).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Home'), centerTitle: true),
      body: Column(
        children: [
          // Search section
          SearchField(
            controller: _searchController,
            onChanged: _onQueryChanged,
            onClear: _clearSearch,
            hintText: 'Search medicines...',
          ),
          ResultsCount(
            resultsCount: results.length,
            totalCount: total,
            query: query,
            isLoading: isLoading,
          ),
          // Search results
          Expanded(
            flex: query.isEmpty ? 0 : 1,
            child: switch ((error, isLoading)) {
              (final String message, _) => CatalogueError(
                message: message,
                onRetry: () => catalogue.clearError(),
              ),
              (_, true) => const Center(child: CircularProgressIndicator()),
              _ =>
                query.isEmpty
                    ? const SizedBox.shrink()
                    : results.isEmpty
                        ? NoResults(query: query)
                        : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: results.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final medicine = results[index];
                          final quantity = context
                              .watch<OrderProvider>()
                              .quantityOf(medicine);

                          return MedicineRow(
                            medicine: medicine,
                            quantity: quantity,
                            onAdd: () => _addItem(medicine),
                            onRemove: () => _removeItem(medicine, quantity),
                          );
                        },
                      ),
            },
          ),
          // Quick-access tiles (shown when not searching)
          if (query.isEmpty)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '$countedCount of $total counted - ${formatCentavos(totalValue)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DashboardTile(
                    icon: Icons.event_busy_outlined,
                    title: 'Expiring Meds',
                    subtitle: '$expiredCount expired · $expiringSoonCount expiring ≤30 days',
                    onTap: () => context.pushNamed('home-expiring'),
                  ),
                  const SizedBox(height: 12),
                  DashboardTile(
                    icon: Icons.qr_code_scanner_outlined,
                    title: 'Scan Prescription',
                    subtitle: 'Handwrite or photograph a prescription',
                    onTap: () => context.pushNamed('home-scan'),
                  ),
                  const SizedBox(height: 12),
                  DashboardTile(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    subtitle: 'Your account and sign out',
                    onTap: () => context.pushNamed('home-profile'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
