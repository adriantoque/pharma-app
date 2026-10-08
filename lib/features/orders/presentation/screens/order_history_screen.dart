import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/pagination_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/order_history_model.dart';
import '../../data/repositories/order_history_repository.dart';
import '../providers/order_history_provider.dart';

/// The Orders tab's history: approved and rejected orders, searchable.
///
/// Split out from the Order List because the two answer different questions.
/// The list is work to do -- new orders waiting for a decision. History is a
/// record -- what was decided and when. A single screen trying to be both puts
/// the thing that needs action next to a hundred things that do not.
///
/// Reached from the Order List's AppBar. Nested under it so the back arrow
/// returns to the list rather than to another tab.
///
/// A [StatelessWidget] whose only job is to put the provider above the body.
/// The body's own `context` is what every `context.read` inside it resolves
/// against, and Provider only looks *up* the tree -- a provider created inside
/// the same `build()` that returns it would be invisible to that widget's own
/// methods, which is exactly why the screen was silent before.
class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OrderHistoryProvider>(
      create: (ctx) {
        final uid = ctx.read<AuthProvider>().user?.id ?? '';
        final repository = ctx.read<OrderHistoryRepositoryFactory>()(uid);
        return OrderHistoryProvider(repository: repository);
      },
      child: const _OrderHistoryBody(),
    );
  }
}

/// Everything below the provider. Its `context` can see it.
class _OrderHistoryBody extends StatefulWidget {
  const _OrderHistoryBody();

  @override
  State<_OrderHistoryBody> createState() => _OrderHistoryBodyState();
}

class _OrderHistoryBodyState extends State<_OrderHistoryBody> {
  final TextEditingController _controller = TextEditingController();

  static const int _pageSize = 10;

  /// Which page of the filtered list is on screen. Clamped on read rather
  /// than written -- see [_effectivePage].
  int _currentPage = 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The page number actually rendered, which is [_currentPage] pulled back
  /// inside the current range of pages.
  ///
  /// An approval made on the Order List, or a filter change, can drop the
  /// visible list below the page the user was on. Corrected on read rather
  /// than reset on every change, so a user on a valid page stays there.
  int _effectivePage(int pageCount) => _currentPage.clamp(1, pageCount);

  /// Pages the current filter and query produce, at least one so the range
  /// arithmetic has something to hold onto even for an empty list.
  static int _pageCountFor(int itemCount) =>
      itemCount == 0 ? 1 : (itemCount + _pageSize - 1) ~/ _pageSize;

  void _resetPage() {
    if (_currentPage != 1) setState(() => _currentPage = 1);
  }

  void _onQueryChanged(String value) {
    context.read<OrderHistoryProvider>().updateQuery(value);
    _resetPage();
  }

  void _clearSearch() {
    _controller.clear();
    context.read<OrderHistoryProvider>().clearQuery();
    _resetPage();
  }

  void _onFilterSelected(HistoryFilter filter) {
    context.read<OrderHistoryProvider>().setFilter(filter);
    _resetPage();
  }

  Future<void> _jumpToPage(int pageCount, int current) async {
    final entered = await showDialog<int>(
      context: context,
      builder: (_) => JumpToPageDialog(
        current: current,
        maxPage: pageCount,
      ),
    );
    if (entered == null || !mounted) return;
    setState(() => _currentPage = entered);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<OrderHistoryProvider>();
    final results = provider.results;

    final pageCount = _pageCountFor(results.length);
    final page = _effectivePage(pageCount);
    final startIndex = (page - 1) * _pageSize;
    final pageItems = results
        .skip(startIndex)
        .take(_pageSize)
        .toList(growable: false);
    final firstItem = results.isEmpty ? 0 : startIndex + 1;
    final lastItem = results.isEmpty
        ? 0
        : (startIndex + pageItems.length).clamp(0, results.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _SearchRow(
            controller: _controller,
            onChanged: _onQueryChanged,
            onClear: _clearSearch,
          ),
          _FilterBar(
            selected: provider.filter,
            counts: provider.counts,
            onSelected: _onFilterSelected,
          ),
          Expanded(
            child: switch ((provider.error, provider.isLoading)) {
              (final String message, _) => _Message(
                  icon: Icons.cloud_off_outlined,
                  title: 'History did not load',
                  detail: message,
                  colour: theme.colorScheme.error,
                ),
              (_, true) => const Center(child: CircularProgressIndicator()),
              _ when provider.totalCount == 0 => const _Message(
                  icon: Icons.receipt_long_outlined,
                  title: 'No orders in history yet',
                  detail: 'Approved and rejected orders appear here once '
                      'a cashier acts on them.',
                ),
              _ when results.isEmpty => _Message(
                  icon: Icons.search_off_outlined,
                  title: 'Nothing matches',
                  detail: provider.query.isEmpty
                      ? 'No order has this status.'
                      : 'No order matches "${provider.query.trim()}".',
                ),
              _ => ListView.separated(
                  // Keyed on the page so the list scroll position resets when
                  // the page changes.
                  key: ValueKey('history-page-$page'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: pageItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _HistoryCard(order: pageItems[index]),
                  ),
                ),
            },
          ),
          // Drawn only when there is more than one page. An empty list, an
          // error, or a page worth of results all render the body alone -- a
          // pager reading "Page 1 of 1" is chrome with nothing to say.
          if (pageCount > 1 &&
              provider.error == null &&
              !provider.isLoading &&
              results.isNotEmpty)
            PaginationBar(
              page: page,
              pageCount: pageCount,
              firstItem: firstItem,
              lastItem: lastItem,
              totalItems: results.length,
              onPrevious: page > 1
                  ? () => setState(() => _currentPage = page - 1)
                  : null,
              onNext: page < pageCount
                  ? () => setState(() => _currentPage = page + 1)
                  : null,
              onTapPage: () => _jumpToPage(pageCount, page),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search and filter
// ---------------------------------------------------------------------------

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: 'Search orders',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear',
                  onPressed: onClear,
                ),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final HistoryFilter selected;
  final Map<HistoryFilter, int> counts;
  final ValueChanged<HistoryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final filter in HistoryFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                showCheckmark: false,
                selected: filter == selected,
                onSelected: (_) => onSelected(filter),
                label: Text('${filter.label} ${counts[filter] ?? 0}'),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History card
// ---------------------------------------------------------------------------

/// One order in history. Expandable to show its lines. No action buttons:
/// once an order is here, its decision has been made.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.order});

  final OrderHistory order;

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
            _statusIcon(order.status),
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
            '${order.items.length} item(s) · '
            '${order.formattedDate(context: context)}',
            style: theme.textTheme.bodySmall?.copyWith(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _statusIcon(OrderStatus status) => switch (status) {
        OrderStatus.approved => Icons.check_circle_outline,
        OrderStatus.rejected => Icons.cancel_outlined,
        OrderStatus.new_ => Icons.pending_actions,
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final OrderStatus status;

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

// ---------------------------------------------------------------------------
// Empty / error bodies
// ---------------------------------------------------------------------------

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
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
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