import 'package:flutter/material.dart';

import '../../../../core/widgets/feature_placeholder.dart';

/// Reached from the Home tile "Sales & Reports".
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales & Reports')),
      body: const FeaturePlaceholder(
        icon: Icons.bar_chart_outlined,
        message: 'Sales & Reports coming next',
      ),
    );
  }
}
