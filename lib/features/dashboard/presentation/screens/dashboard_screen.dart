import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/dashboard_tile.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home'), centerTitle: true),
      // pushNamed rather than goNamed: these are child pages of the Home
      // branch, so pushing keeps Home selected in the bottom bar and gives each
      // page a back arrow. goNamed would replace the tab and strand the user.
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DashboardTile(
            icon: Icons.inventory_2_outlined,
            title: 'Real Time Inventory',
            subtitle: 'Live stock levels across the pharmacy',
            onTap: () => context.pushNamed('home-inventory'),
          ),
          const SizedBox(height: 12),
          DashboardTile(
            icon: Icons.bar_chart_outlined,
            title: 'Sales & Reports',
            subtitle: 'Revenue and dispensing trends',
            onTap: () => context.pushNamed('home-reports'),
          ),
          const SizedBox(height: 12),
          DashboardTile(
            icon: Icons.event_busy_outlined,
            title: 'Expiring Meds',
            subtitle: 'Medicines nearing their expiry date',
            onTap: () => context.pushNamed('home-expiring'),
          ),
        ],
      ),
    );
  }
}
