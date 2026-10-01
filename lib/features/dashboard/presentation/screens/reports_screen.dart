import 'package:flutter/material.dart';

import '../../../../core/widgets/feature_placeholder.dart';

/// Reached from its own bottom-nav tab.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Reports is its own tab root, so its title is centred.
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
      body: const FeaturePlaceholder(
        icon: Icons.bar_chart_outlined,
        message: 'Sales & Reports coming next',
      ),
    );
  }
}
