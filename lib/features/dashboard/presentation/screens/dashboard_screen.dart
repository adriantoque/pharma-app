import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/currency.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/data/models/order_history_model.dart';
import '../../../orders/data/repositories/order_history_repository.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../../../search/presentation/providers/attention_data.dart';

// ---------------------------------------------------------------------------
// Helpers & Utilities
// ---------------------------------------------------------------------------

/// Text and dot colour for a stock state.
///
/// Mirrors the copy in `inventory_screen.dart`: the same four states, the same
/// dark-mode handling. Taking [StockState] rather than the string the mock
/// model used to hand back is what lets `unknown` get its own colour instead of
/// falling through to the healthy one.
abstract final class _StockColors {
  /// Amber used for the expiry and low-stock attention tiles, which colour a
  /// whole tile rather than a single stock line.
  static Color warning(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFFFFD98A) : const Color(0xFF8A5A00);
  }

  static Color status(BuildContext context, StockState state) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return switch (state) {
      StockState.outOfStock => scheme.error,
      StockState.low => dark ? const Color(0xFFFFD98A) : const Color(0xFF8A5A00),
      StockState.unknown => scheme.outline,
      StockState.available => scheme.onSurfaceVariant,
    };
  }

  /// Pill background and foreground for a counted state.
  static (Color, Color) pill(BuildContext context, StockState state) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return switch (state) {
      StockState.outOfStock => (scheme.errorContainer, scheme.onErrorContainer),
      StockState.low => dark
          ? (const Color(0xFF4A3600), const Color(0xFFFFD98A))
          : (const Color(0xFFFFE8B8), const Color(0xFF6B4A00)),
      _ => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
  }
}

// ---------------------------------------------------------------------------
// Models & Domain Layer
// ---------------------------------------------------------------------------

abstract interface class SaleRecord {
  DateTime get completedAt;
  int get itemCount;
  int get totalCentavos;
}

/// Adapts a completed order to the [SaleRecord] shape [SalesSummary] reads.
///
/// [OrderHistory] already carries a real [OrderHistory.time] and an item list,
/// but names them differently and has no item total, so the fold belongs here
/// rather than in the summary.
class _HistorySale implements SaleRecord {
  const _HistorySale(this.order);

  final OrderHistory order;

  @override
  DateTime get completedAt => order.time;

  @override
  int get totalCentavos => order.totalCentavos;

  @override
  int get itemCount =>
      order.items.fold(0, (total, line) => total + line.quantity);
}

/// Today's takings, derived from completed orders.
///
/// Deliberately its own provider rather than a getter on [OrderProvider]: that
/// one is the basket being built, this is what has already been sold. They come
/// from different repositories and change for different reasons.
///
/// Reads the same [OrderHistoryRepository] the Orders tab does, so both screens
/// agree on what has been sold.
class TodaySalesProvider extends ChangeNotifier {
  TodaySalesProvider({
    required OrderHistoryRepository Function() historyFactory,
  }) {
    _subscription = historyFactory().watchAll().listen(
      (orders) {
        _summary = SalesSummary.fromSales(
          orders.map(_HistorySale.new),
          DateTime.now(),
        );
        notifyListeners();
      },
      // A history read that fails leaves the card showing zero rather than an
      // error: the dashboard reports state, and a shop floor losing the network
      // is routine.
      onError: (_) {},
    );
  }

  late final StreamSubscription<List<OrderHistory>> _subscription;

  SalesSummary _summary = SalesSummary.empty();

  /// Today's totals. Empty until the first order completes.
  SalesSummary get summary => _summary;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

@immutable
class SalesSummary {
  const SalesSummary({
    required this.totalCentavos,
    required this.orderCount,
    required this.itemsSold,
    required this.hourly,
    required this.currentBucket,
    required this.changeVsYesterday,
  });

  static const int openHour = 8;
  static const int closeHour = 18;
  static const int bucketCount = closeHour - openHour + 1;

  final int totalCentavos;
  final int orderCount;
  final int itemsSold;
  final List<int> hourly;
  final int currentBucket;
  final double? changeVsYesterday;

  bool get isEmpty => orderCount == 0;

  int get averageCentavos =>
      orderCount == 0 ? 0 : (totalCentavos / orderCount).round();

  factory SalesSummary.empty([DateTime? now]) =>
      SalesSummary.fromSales(const [], now ?? DateTime.now());

  static int _bucketFor(DateTime time) =>
      time.hour.clamp(openHour, closeHour) - openHour;

  factory SalesSummary.fromSales(Iterable<SaleRecord> sales, DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = DateTime(now.year, now.month, now.day - 1);
    final sameTimeYesterday = DateTime(
      now.year,
      now.month,
      now.day - 1,
      now.hour,
      now.minute,
      now.second,
    );

    var total = 0;
    var orders = 0;
    var items = 0;
    var yesterdaySoFar = 0;
    var yesterdayHadSales = false;
    final hourly = List<int>.filled(bucketCount, 0);

    for (final sale in sales) {
      final at = sale.completedAt;

      if (!at.isBefore(startOfToday)) {
        total += sale.totalCentavos;
        orders++;
        items += sale.itemCount;
        hourly[_bucketFor(at)] += sale.totalCentavos;
      } else if (!at.isBefore(startOfYesterday)) {
        yesterdayHadSales = true;
        if (!at.isAfter(sameTimeYesterday)) {
          yesterdaySoFar += sale.totalCentavos;
        }
      }
    }

    final change = (yesterdayHadSales && yesterdaySoFar > 0)
        ? (total - yesterdaySoFar).toDouble() / yesterdaySoFar
        : null;

    return SalesSummary(
      totalCentavos: total,
      orderCount: orders,
      itemsSold: items,
      hourly: List.unmodifiable(hourly),
      currentBucket: _bucketFor(now),
      changeVsYesterday: change,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SalesSummary &&
      other.totalCentavos == totalCentavos &&
      other.orderCount == orderCount &&
      other.itemsSold == itemsSold &&
      other.currentBucket == currentBucket &&
      other.changeVsYesterday == changeVsYesterday &&
      listEquals(other.hourly, hourly);

  @override
  int get hashCode => Object.hash(
        totalCentavos,
        orderCount,
        itemsSold,
        currentBucket,
        changeVsYesterday,
        Object.hashAll(hourly),
      );
}

// ---------------------------------------------------------------------------
// DashboardScreen
// ---------------------------------------------------------------------------

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.historyFactory});

  /// Builds the [OrderHistoryRepository] "Today's sales" reads from.
  ///
  /// Mirrors `OrdersScreen.historyFactory` so both screens read the same
  /// history. If not provided, a Firestore repository scoped to the signed-in
  /// user is used.
  final OrderHistoryRepository Function()? historyFactory;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const int _attentionPreviewCount = 5;

  void _comingSoon(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = context.watch<MedicineProvider>();
    final attention = catalogue.attention;

    final historyFactory =
        widget.historyFactory ??
        () => context.read<OrderHistoryRepositoryFactory>()(
              context.read<AuthProvider>().user?.id ?? '',
            );

    return ChangeNotifierProvider<TodaySalesProvider>(
      create: (_) => TodaySalesProvider(historyFactory: historyFactory),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Wilma Pharmacy's"),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            // The one search affordance on this screen: opens the full-screen
            // finder, which browses every screen by name.
            IconButton(
              tooltip: 'Search screens',
              icon: const Icon(Icons.manage_search),
              onPressed: () => context.pushNamed('finder'),
            ),
            IconButton(
              tooltip: 'Notifications',
              icon: Badge.count(
                count: attention.total,
                isLabelVisible: attention.total > 0,
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => context.pushNamed('home-notifications'),
            ),
            IconButton(
              tooltip: 'Profile',
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.pushNamed('home-profile'),
            ),
          ],
        ),
        body: _body(attention, catalogue.error, catalogue.isLoading),
      ),
    );
  }

  /// The body of the screen, chosen by the catalogue's state.
  ///
  /// Split out so the error and loading branches come before the browse list:
  /// an empty pharmacy is not a state this app has to handle, whereas a first
  /// read that has not landed is, and showing an empty list during it would read
  /// as "the pharmacy stocks nothing".
  Widget _body(AttentionData attention, String? catalogueError, bool isLoading) {
    if (catalogueError != null) {
      return _CatalogueError(
        message: catalogueError,
        onRetry: () => context.read<MedicineProvider>().clearError(),
      );
    }
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return _browseList(attention);
  }

  Widget _browseList(AttentionData attention) {
    final theme = Theme.of(context);
    final preview = attention.lowStock.take(_attentionPreviewCount).toList();
    final warning = _StockColors.warning(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _TodaySalesCard(onViewReport: () => _comingSoon('Sales report — coming soon')),
        const SizedBox(height: 8),
        _CurrentOrderStrip(onTap: () => context.goNamed('new-sale')),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.goNamed('new-sale'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.point_of_sale_outlined, size: 18),
                SizedBox(width: 6),
                Text('New sale'),
              ],
            ),
          ),
        ),
        Row(
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
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _AttentionTile(
                count: attention.expired,
                label: 'Expired',
                colour: theme.colorScheme.error,
                onTap: () => context.pushNamed('home-expiring'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AttentionTile(
                count: attention.expiringSoon,
                label: 'Expiring soon',
                colour: warning,
                onTap: () => context.pushNamed('home-expiring'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AttentionTile(
                count: attention.lowStock.length,
                label: 'Low stock',
                colour: warning,
                onTap: () => context.goNamed('inventory'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _LowStockCard(
          lines: preview,
          totalCount: attention.lowStock.length,
          onViewAll: () => context.goNamed('inventory'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Catalogue error
// ---------------------------------------------------------------------------

/// Shown when the catalogue failed to load, so the browse list cannot render.
class _CatalogueError extends StatelessWidget {
  const _CatalogueError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Browse-list widgets
// ---------------------------------------------------------------------------

class _TodaySalesCard extends StatelessWidget {
  const _TodaySalesCard({required this.onViewReport});

  final VoidCallback onViewReport;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _dateLabel(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = context.select<TodaySalesProvider, SalesSummary>(
      (today) => today.summary,
    );
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final change = summary.changeVsYesterday;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text("Today's sales", style: muted)),
                Text(_dateLabel(DateTime.now()), style: muted),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatCentavos(summary.totalCentavos),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: summary.isEmpty
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.primary,
              ),
            ),
            if (summary.isEmpty)
              const _EmptySales()
            else ...[
              if (change != null) ...[
                const SizedBox(height: 6),
                _DeltaChip(change: change),
              ],
              const SizedBox(height: 16),
              _HourlyBars(
                values: summary.hourly,
                currentBucket: summary.currentBucket,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _Stat(value: '${summary.orderCount}', label: 'Orders'),
                    VerticalDivider(width: 1),
                    _Stat(value: '${summary.itemsSold}', label: 'Items sold'),
                    VerticalDivider(width: 1),
                    _Stat(
                      value: formatCentavos(summary.averageCentavos),
                      label: 'Average',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Divider(height: 16),
              InkWell(
                onTap: onViewReport,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'View sales report',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptySales extends StatelessWidget {
  const _EmptySales();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No sales yet today. Completed orders will show up here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.change});

  final double change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final percent = (change * 100).round();

    final (background, foreground, icon) = switch (percent.sign) {
      1 => (
          dark ? const Color(0xFF1E3A24) : const Color(0xFFD7F0DC),
          dark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20),
          Icons.trending_up,
        ),
      -1 => (scheme.errorContainer, scheme.onErrorContainer, Icons.trending_down),
      _ => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          Icons.trending_flat,
        ),
    };

    final text = percent == 0
        ? 'Level with yesterday at this time'
        : '${percent > 0 ? '+' : '-'}${percent.abs()}% vs yesterday at this time';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.labelMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourlyBars extends StatelessWidget {
  const _HourlyBars({required this.values, required this.currentBucket});

  final List<int> values;
  final int currentBucket;

  static const double _height = 56;

  static String _hourLabel(int hour) {
    if (hour == 0) return '12 am';
    if (hour < 12) return '$hour am';
    if (hour == 12) return '12 pm';
    return '${hour - 12} pm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final peak = values.fold<int>(0, (a, b) => a > b ? a : b);
    final label = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    const open = SalesSummary.openHour;
    const close = SalesSummary.closeHour;

    return Semantics(
      label: 'Sales by hour, ${_hourLabel(open)} to ${_hourLabel(close)}',
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: _height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: i > currentBucket || peak == 0
                                ? 4
                                : (_height * values[i] / peak).clamp(4, _height),
                            decoration: BoxDecoration(
                              color: i > currentBucket
                                  ? scheme.surfaceContainerHighest
                                  : i == currentBucket
                                      ? scheme.primary
                                      : scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_hourLabel(open), style: label),
                Text(_hourLabel(((open + close) / 2).round()), style: label),
                Text(_hourLabel(close), style: label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentOrderStrip extends StatelessWidget {
  const _CurrentOrderStrip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (count, total) = context.select<OrderProvider, (int, String)>(
      (order) => (order.itemCount, order.formattedTotal),
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 0
                          ? 'Current order is empty'
                          : 'Current order · ${count == 1 ? '1 item' : '$count items'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (count > 0)
                      Text(
                        '$total so far',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({
    required this.count,
    required this.label,
    required this.colour,
    required this.onTap,
  });

  final int count;
  final String label;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: count == 0 ? theme.colorScheme.onSurfaceVariant : colour,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({
    required this.lines,
    required this.totalCount,
    required this.onViewAll,
  });

  final List<MedicineModel> lines;
  final int totalCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (lines.isEmpty) {
      return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                'Nothing is running low.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < lines.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _LowStockRow(medicine: lines[index]),
          ],
          if (totalCount > lines.length) ...[
            const Divider(height: 1),
            InkWell(
              onTap: onViewAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'View all $totalCount low stock lines',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.medicine});

  final MedicineModel medicine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, state) = medicine.stockLine;
    final (background, foreground) = _StockColors.pill(context, state);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _StockColors.status(context, state),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${medicine.stock ?? 0}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
