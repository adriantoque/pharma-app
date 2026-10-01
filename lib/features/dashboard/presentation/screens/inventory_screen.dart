import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/currency.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../widgets/stock_sheet.dart';

/// Reached from the Home tile "Real Time Inventory".
///
/// Where the shelf counts are actually taken. The price list knows what
/// everything costs and, for the imported lines, nothing at all about how many
/// are on the shelf -- so this screen opens on mostly-uncounted data and its real
/// job is turning those into numbers. That is why the uncounted filter is the
/// default rather than a nicety: after a stock-take the useful question is what
/// is still unknown, and the answer changes as the work goes on.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

/// Which lines the list is showing.
///
/// A filter on [StockState] rather than a free-text one, because the three states
/// are exactly the three things worth acting on and they cannot be expressed as a
/// search term.
enum _StockFilter {
  uncounted('Not counted'),
  outOfStock('Out of stock'),
  low('Low'),
  all('All');

  const _StockFilter(this.label);

  final String label;

  /// Whether a line in [state] belongs in this filter.
  bool accepts(StockState state) => switch (this) {
        _StockFilter.uncounted => state == StockState.unknown,
        _StockFilter.outOfStock => state == StockState.outOfStock,
        _StockFilter.low => state == StockState.low,
        _StockFilter.all => true,
      };
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _controller = TextEditingController();
  _StockFilter _filter = _StockFilter.uncounted;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The lines the current filter and query select, in price-list order.
  List<MedicineModel> _visible(MedicineProvider catalogue) {
    final needle = _controller.text.trim();
    return catalogue
        .all()
        .where((medicine) => _filter.accepts(medicine.stockState))
        .where((medicine) => needle.isEmpty || medicine.matches(needle))
        .toList();
  }

  Future<void> _edit(MedicineModel medicine) async {
    await showStockSheet(context, medicine: medicine);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watched: a count saved on this screen, or by another device, has to move
    // both the list and the tally.
    final catalogue = context.watch<MedicineProvider>();
    final all = catalogue.all();
    final visible = _visible(catalogue);

    return Scaffold(
      appBar: AppBar(title: const Text('Real Time Inventory'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Find a product',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear',
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          _Tally(catalogue: all),
          _FilterBar(
            selected: _filter,
            counts: {
              for (final filter in _StockFilter.values)
                filter: all.where((m) => filter.accepts(m.stockState)).length,
            },
            onSelected: (filter) => setState(() => _filter = filter),
          ),
          Expanded(
            child: switch ((catalogue.error, catalogue.isLoading)) {
              (final String message, _) => _Message(
                icon: Icons.cloud_off_outlined,
                title: 'The price list did not load',
                detail: message,
                colour: theme.colorScheme.error,
              ),
              (_, true) => const Center(child: CircularProgressIndicator()),
              _ when all.isEmpty => _Message(
                icon: Icons.inventory_2_outlined,
                title: 'No products yet',
                detail: 'The price list has to be imported before stock can be '
                    'counted.',
              ),
              _ when visible.isEmpty => _Message(
                icon: Icons.check_circle_outline,
                title: 'Nothing here',
                detail: _controller.text.trim().isEmpty
                    ? 'No product is in this state.'
                    : 'No match for "${_controller.text.trim()}" in this state.',
              ),
              _ => ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final medicine = visible[index];
                    return _StockRow(
                      medicine: medicine,
                      onTap: () => _edit(medicine),
                    );
                  },
                ),
            },
          ),
        ],
      ),
    );
  }
}

/// "142 of 490 counted", with the value of what is there.
///
/// The value is of the counted lines only. Putting a peso total next to an
/// uncounted list would read as a stock valuation, and stock value is not
/// something this app knows -- it has counts and unit prices, not costs, and
/// those are different numbers.
class _Tally extends StatelessWidget {
  const _Tally({required this.catalogue});

  final List<MedicineModel> catalogue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counted = catalogue.where((m) => m.stock != null).toList();
    final units = counted.fold<int>(0, (sum, m) => sum + m.stock!);
    final value = counted.fold<int>(
      0,
      (sum, m) => sum + m.priceCentavos * m.stock!,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${counted.length} of ${catalogue.length} counted',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (counted.isNotEmpty)
            Text(
              '${_units(units)} units · ${formatCentavos(value)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  static String _units(int units) => units.toString();
}

/// The stock-state chips.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final _StockFilter selected;
  final Map<_StockFilter, int> counts;
  final ValueChanged<_StockFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final filter in _StockFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: filter == selected,
                onSelected: (_) => onSelected(filter),
                label: Text('${filter.label} (${counts[filter] ?? 0})'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.medicine, required this.onTap});

  final MedicineModel medicine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, state) = medicine.stockLine;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    medicine.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
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
            ),
            const SizedBox(width: 12),
            Text(
              medicine.formattedPrice,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

/// The empty and error bodies, so a screen with nothing to list says which of
/// the several reasons it is.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    this.colour,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colour ?? theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              detail,
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
