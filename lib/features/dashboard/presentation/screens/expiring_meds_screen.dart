import 'package:flutter/material.dart';

import '../../../../core/widgets/feature_placeholder.dart';

/// Reached from the Home tile "Expiring Meds".
///
/// Nested under the Home branch, so the bottom bar keeps Home selected and the
/// back arrow returns to the tile the user actually tapped from.
class ExpiringMedsScreen extends StatelessWidget {
  const ExpiringMedsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expiring Meds')),
      body: const FeaturePlaceholder(
        icon: Icons.event_busy_outlined,
        message: 'Expiring Meds coming next',
      ),
    );
  }
}
