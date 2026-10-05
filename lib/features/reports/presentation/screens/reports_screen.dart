import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Report Data Models
// ---------------------------------------------------------------------------

enum ReportPeriod { today, thisWeek, thisMonth, custom }

class TopProductReportItem {
  const TopProductReportItem({
    required this.name,
    required this.unitsSold,
    required this.revenueCentavos,
    required this.stockRemaining,
  });

  final String name;
  final int unitsSold;
  final int revenueCentavos;
  final int stockRemaining;
}

class CategorySalesItem {
  const CategorySalesItem({
    required this.categoryName,
    required this.percentage,
    required this.totalCentavos,
  });

  final String categoryName;
  final double percentage;
  final int totalCentavos;
}

// ---------------------------------------------------------------------------
// Sales Report Screen
// ---------------------------------------------------------------------------

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.repository});

  final dynamic repository; // Kept for compatibility with existing router/tests

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.today;
  DateTimeRange? _customDateRange;

  // Data fetched from repository
  List<TopProductReportItem> _topProducts = [];
  List<CategorySalesItem> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      // In a real app, we would call repository.getTopProducts(_selectedPeriod)
      // For now, we simulate the async fetch to bridge the gap
      await Future.delayed(const Duration(milliseconds: 500));

      // Note: To fully implement, replace these with repository calls
      // e.g. _topProducts = await widget.repository?.getTopSellers() ?? [];

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _exportReport(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting report as $format...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedPeriod = ReportPeriod.custom;
      });
    }
  }

  String _getPeriodLabel() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case ReportPeriod.today:
        return 'Today (${now.day}/${now.month}/${now.year})';
      case ReportPeriod.thisWeek:
        return 'This Week';
      case ReportPeriod.thisMonth:
        return '${_months[now.month - 1]} ${now.year}';
      case ReportPeriod.custom:
        if (_customDateRange == null) return 'Custom Range';
        final start = _customDateRange!.start;
        final end = _customDateRange!.end;
        return '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
    }
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales & Analytics Report'),
        // Every tab title sits on the screen's centreline; only a pushed child
        // page goes leading-aligned.
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export Report',
            onSelected: _exportReport,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'PDF',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined),
                    SizedBox(width: 8),
                    Text('Export as PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'CSV/Excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined),
                    SizedBox(width: 8),
                    Text('Export as CSV'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Period Selector Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Today'),
                  selected: _selectedPeriod == ReportPeriod.today,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedPeriod = ReportPeriod.today);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('This Week'),
                  selected: _selectedPeriod == ReportPeriod.thisWeek,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedPeriod = ReportPeriod.thisWeek);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('This Month'),
                  selected: _selectedPeriod == ReportPeriod.thisMonth,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedPeriod = ReportPeriod.thisMonth);
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(_selectedPeriod == ReportPeriod.custom && _customDateRange != null
                      ? 'Custom (${_customDateRange!.start.day}/${_customDateRange!.start.month})'
                      : 'Custom Range'),
                  onPressed: _selectCustomRange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Period Active Notice
          Text(
            _getPeriodLabel(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Key Performance Indicator (KPI) Grid
          const Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: 'Total Revenue',
                  value: '₱48,250.00',
                  delta: '+14.2%',
                  isPositive: true,
                  icon: Icons.payments_outlined,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: 'Gross Margin',
                  value: '38.5%',
                  delta: '₱18,576.25',
                  isPositive: true,
                  icon: Icons.pie_chart_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: 'Total Transactions',
                  value: '58 orders',
                  delta: 'Avg ₱831.90',
                  isPositive: true,
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: 'Units Sold',
                  value: '431 items',
                  delta: '7.4 per order',
                  isPositive: true,
                  icon: Icons.inventory_2_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Revenue Breakdown Chart Card
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Revenue Trend',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Peak: 2:00 PM (₱12,400)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(
                    height: 140,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _SimpleBarChart(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Category Share Breakdown
          Text(
            'Sales by Category',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _categories
                    .map((cat) => _CategoryRow(item: cat))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Top Selling Items Table Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Selling Products',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View Catalogue'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Top Products List Card
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _topProducts.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _TopProductRow(rank: i + 1, item: _topProducts[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPI Widget
// ---------------------------------------------------------------------------

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.delta,
    required this.isPositive,
    required this.icon,
  });

  final String title;
  final String value;
  final String delta;
  final bool isPositive;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              delta,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isPositive
                    ? (theme.brightness == Brightness.dark
                        ? Colors.greenAccent
                        : Colors.green.shade800)
                    : theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category Share Row
// ---------------------------------------------------------------------------

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.item});

  final CategorySalesItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentStr = '${(item.percentage * 100).toStringAsFixed(0)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.categoryName, style: theme.textTheme.bodyMedium),
              Text(
                '₱${(item.totalCentavos / 100).toStringAsFixed(2)} ($percentStr)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: item.percentage,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top Product Row
// ---------------------------------------------------------------------------

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({required this.rank, required this.item});

  final int rank;
  final TopProductReportItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: rank == 1
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: rank == 1
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item.unitsSold} units sold · ${item.stockRemaining} left in stock',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: item.stockRemaining <= 5
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₱${(item.revenueCentavos / 100).toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lightweight Visual Bar Chart
// ---------------------------------------------------------------------------

class _SimpleBarChart extends StatelessWidget {
  const _SimpleBarChart();

  static const List<double> _hourlyData = [
    0.2, 0.35, 0.6, 0.8, 1.0, 0.75, 0.9, 0.5, 0.3, 0.2
  ];
  static const List<String> _labels = [
    '8a', '9a', '10a', '11a', '12p', '1p', '2p', '3p', '4p', '5p'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < _hourlyData.length; i++)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: _hourlyData[i],
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == 4 || i == 6
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _labels[i],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
