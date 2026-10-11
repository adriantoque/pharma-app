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
import '../widgets/stock_sheet.dart';

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
  static Color status(BuildContext context, StockState state) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return switch (state) {
      StockState.outOfStock => scheme.error,
      StockState.low =>
        dark ? const Color(0xFFFFD98A) : const Color(0xFF8A5A00),
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
      StockState.low =>
        dark
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
    required this.yesterdayCentavos,
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
  final int yesterdayCentavos;
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
    var yesterdayTotal = 0;
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
        yesterdayTotal += sale.totalCentavos;
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
      yesterdayCentavos: yesterdayTotal,
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
      other.yesterdayCentavos == yesterdayCentavos &&
      other.orderCount == orderCount &&
      other.itemsSold == itemsSold &&
      other.currentBucket == currentBucket &&
      other.changeVsYesterday == changeVsYesterday &&
      listEquals(other.hourly, hourly);

  @override
  int get hashCode => Object.hash(
    totalCentavos,
    yesterdayCentavos,
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
          leadingWidth: 48,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12, top: 10, bottom: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/baseIcon.png',
                  fit: BoxFit.cover,
                  semanticLabel: 'PharmaGuide logo',
                ),
              ),
            ),
          ),
          title: const Text("Wilma Pharmacy's"),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            // Only an admin sees the way into the workspace; everyone else
            // has no business there and no door to it.
            if (context.select<AuthProvider, bool>((a) => a.isAdmin))
              IconButton(
                tooltip: 'Admin',
                icon: const Icon(Icons.admin_panel_settings_outlined),
                onPressed: () => context.pushNamed('admin'),
              ),
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
  Widget _body(
    AttentionData attention,
    String? catalogueError,
    bool isLoading,
  ) {
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        const _TodaySalesCard(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 6,
              child: _CurrentOrderStrip(
                onTap: () => context.goNamed('new-sale'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: SizedBox(
                height: 42,
                child: FilledButton(
                  onPressed: () => context.goNamed('new-sale'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1678ED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'New sale',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.document_scanner_outlined,
                label: 'Scan',
                onTap: () => context.pushNamed('home-scan'),
              ),
            ),
            Expanded(
              child: _QuickAction(
                icon: Icons.inventory_2_outlined,
                label: 'Add stock',
                onTap: () => context.goNamed('inventory'),
              ),
            ),
            Expanded(
              child: _QuickAction(
                icon: Icons.assignment_return_outlined,
                label: 'Returns',
                onTap: () => _comingSoon('Returns — coming soon'),
              ),
            ),
            Expanded(
              child: _QuickAction(
                icon: Icons.people_outline,
                label: 'Customers',
                onTap: () => _comingSoon('Customers — coming soon'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text('Low stock', style: theme.textTheme.titleMedium),
            ),
            TextButton(
              onPressed: () => context.goNamed('inventory'),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
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
  const _TodaySalesCard();

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _dateLabel(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = context.select<TodaySalesProvider, SalesSummary>(
      (today) => today.summary,
    );
    const white = Colors.white;
    final smallStyle = theme.textTheme.labelSmall?.copyWith(
      color: white.withValues(alpha: 0.78),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2589F5), Color(0xFF0861D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x262677E5),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text("Today's sales", style: smallStyle)),
                Text(_dateLabel(DateTime.now()), style: smallStyle),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              formatCentavos(summary.totalCentavos),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: white,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            Text(
              'Yesterday ${formatCentavos(summary.yesterdayCentavos)}',
              style: smallStyle,
            ),
            const SizedBox(height: 10),
            _SalesTrend(
              values: summary.hourly,
              currentBucket: summary.currentBucket,
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _SalesMetric(
                    value: '${summary.orderCount}',
                    label: 'Orders',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SalesMetric(
                    value: '${summary.itemsSold}',
                    label: 'Items sold',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SalesMetric(
                    value: formatCentavos(summary.averageCentavos),
                    label: 'Avg order',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesTrend extends StatelessWidget {
  const _SalesTrend({required this.values, required this.currentBucket});

  final List<int> values;
  final int currentBucket;

  @override
  Widget build(BuildContext context) {
    final peak = values.fold<int>(0, (highest, value) {
      return value > highest ? value : highest;
    });

    return Semantics(
      label: 'Sales trend by hour',
      child: Row(
        children: [
          for (var index = 0; index < values.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: index > currentBucket || peak == 0
                        ? 1
                        : (values[index] / peak).clamp(0.16, 1),
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.26),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(
                        alpha: index > currentBucket ? 0.34 : 0.96,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SalesMetric extends StatelessWidget {
  const _SalesMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1680F5), size: 21),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                color: const Color(0xFF1680F5),
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 0
                          ? 'Current order is empty'
                          : 'Current order · ${count == 1 ? '1 item' : '$count items'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (count > 0)
                      Text(
                        '$total so far',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.primary,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  medicine.stock == null ? 'Count' : '${medicine.stock} left',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => showStockSheet(context, medicine: medicine),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(48, 26),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Restock'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
