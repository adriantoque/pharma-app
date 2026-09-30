import 'package:flutter/material.dart';

import '../../../../core/widgets/feature_placeholder.dart';

/// Reached from the Home tile "Real Time Inventory".
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Real Time Inventory')),
      body: const FeaturePlaceholder(
        icon: Icons.inventory_2_outlined,
        message: 'Real Time Inventory coming next',
      ),
    );
  }
}
