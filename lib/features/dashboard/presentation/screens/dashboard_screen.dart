import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../admin/presentation/providers/store_settings_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../orders/data/models/order_history_model.dart';
import '../../../orders/data/repositories/order_history_repository.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../reports/presentation/providers/reports_provider.dart';
import '../../../search/data/sync/sync_status.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../providers/notification_provider.dart';

/// The Home tab.
///
/// Staff only. Every figure and action here is something a counter staff
/// member does or needs to know. Stock *counting* stays an admin task, but
/// the shelf shortfall is a number the counter needs: it tells them what they
/// will have to say "we're out" about before the customer asks.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.select<NotificationsProvider, int>(
      (p) => p.unreadCount,
    );

    return Scaffold(
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
          IconButton(
            tooltip: 'Search screens',
            icon: const Icon(Icons.manage_search),
            onPressed: () => context.pushNamed('finder'),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          const _SyncCard(),
          const SizedBox(height: 12),
          const _PendingOrdersCard(),
          const SizedBox(height: 12),
          const _AttentionRow(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: _CartButton(
                  onTap: () => context.goNamed('home'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: _ActionButton(
                  icon: Icons.add,
                  label: 'New order',
                  onTap: () => context.goNamed('home'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.document_scanner_outlined,
            label: 'Scan',
            onTap: () => context.pushNamed('home-scan'),
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: Icons.healing_outlined,
            label: 'Symptom guide',
            onTap: () => context.pushNamed('home-symptom-guide'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sync status
// ---------------------------------------------------------------------------

/// Whether offline work has reached the server. Reads the same [SyncStatus]
/// as the shell's offline banner, so the two cannot disagree.
class _SyncCard extends StatelessWidget {
  const _SyncCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = context.select<MedicineProvider, SyncStatus>(
      (p) => p.syncStatus,
    );

    final waiting = status.hasPendingChanges;
    final count = status.pendingWriteCount;

    final icon =
        waiting ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined;
    final text = waiting
        ? (count == 1
            ? '1 change waiting to sync'
            : '$count changes waiting to sync')
        : 'All changes synced';
    final background =
        waiting ? scheme.tertiaryContainer : scheme.surfaceContainerLow;
    final foreground =
        waiting ? scheme.onTertiaryContainer : scheme.onSurfaceVariant;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pending orders
// ---------------------------------------------------------------------------

/// Orders waiting for cashier approval, opening the Orders tab.
///
/// Reads the same per-user history the Orders tab reads, through the factory
/// registered in `main.dart`. Offline that is the in-memory history; online it
/// is Firestore. A signed-out state shows zero rather than subscribing.
class _PendingOrdersCard extends StatefulWidget {
  const _PendingOrdersCard();

  @override
  State<_PendingOrdersCard> createState() => _PendingOrdersCardState();
}

class _PendingOrdersCardState extends State<_PendingOrdersCard> {
  Stream<List<OrderHistory>>? _orders;
  String? _uid;

  @override
  Widget build(BuildContext context) {
    final uid = context.select<AuthProvider, String?>((a) => a.user?.id);

    // Subscribe once per account. Creating the stream on every build would
    // resubscribe to Firestore each time the dashboard rebuilds.
    if (uid != _uid) {
      _uid = uid;
      _orders = uid == null
          ? null
          : context.read<OrderHistoryRepositoryFactory>()(uid).watchAll();
    }

    return StreamBuilder<List<OrderHistory>>(
      stream: _orders,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _PendingCard(
            count: 0,
            failed: true,
            onTap: () => context.goNamed('orders'),
          );
        }
        return _PendingCard(
          count: _countNew(snapshot.data),
          failed: false,
          onTap: () => context.goNamed('orders'),
        );
      },
    );
  }

  /// Orders still awaiting approval. Null data (the stream has not answered
  /// yet) counts as zero rather than a figure that might be wrong.
  static int _countNew(List<OrderHistory>? orders) {
    if (orders == null) return 0;
    return orders.where((o) => o.status == OrderStatus.new_).length;
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.count,
    required this.failed,
    required this.onTap,
  });

  final int count;
  final bool failed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasPending = count > 0;

    final foreground = failed
        ? scheme.onErrorContainer
        : hasPending
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant;
    final background = failed
        ? scheme.errorContainer
        : hasPending
            ? scheme.primaryContainer
            : scheme.surfaceContainerLow;

    final String text;
    if (failed) {
      text = 'Could not load orders';
    } else if (hasPending) {
      text = count == 1
          ? '1 order needs approval'
          : '$count orders need approval';
    } else {
      text = 'No orders waiting for approval';
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: background,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                failed ? Icons.error_outline : Icons.pending_actions_outlined,
                color: foreground,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: foreground,
                    fontWeight: hasPending ? FontWeight.w600 : null,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expiry and stock attention
// ---------------------------------------------------------------------------

/// Lines expiring soon and shelf shortfall. Each opens a staff screen where
/// the problem is handled: Expiring Meds for dates, Medicine for stock and
/// counting.
class _AttentionRow extends StatelessWidget {
  const _AttentionRow();

  @override
  Widget build(BuildContext context) {
    final medicines = context.watch<MedicineProvider>().all();

    final expirySoonDays = context.watch<StoreSettingsProvider>()
        .settings
        .expiryWarningDays;

    final expiring = medicines.where((m) {
      if (m.expiryDate == null) return false;
      if (m.isExpired) return true;
      final days = m.daysUntilExpiry;
      return days != null && days <= expirySoonDays;
    }).length;

    // The shortfall the alerts carry, in units. Computed in the reports
    // repository against Store settings' coverage window, so this tile and
    // the admin dashboard's Low Stock Alerts always agree. Uncounted lines
    // are excluded from the sum: "not counted" is its own problem and folding
    // it into a unit count would report a fresh import as thousands short.
    final reports = context.watch<ReportsProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.read<ReportsProvider>().ensureLowStockLoaded();
    });
    final shortUnits = reports.lowStockAlerts
        .where((alert) => !alert.isStockUncounted)
        .fold(0, (sum, alert) => sum + alert.deficit);

    return Row(
      children: [
        Expanded(
          child: _CountTile(
            icon: Icons.event_busy_outlined,
            count: expiring,
            label: expiring == 1 ? 'line expiring' : 'lines expiring',
            onTap: () => context.pushNamed('home-expiring'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CountTile(
            icon: Icons.inventory_2_outlined,
            count: shortUnits,
            label: shortUnits == 1 ? 'unit short' : 'units short',
            onTap: () => context.goNamed('medicines'),
          ),
        ),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final attention = count > 0;

    final foreground =
        attention ? scheme.onErrorContainer : scheme.onSurfaceVariant;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: attention ? scheme.errorContainer : scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: attention ? foreground : null,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Counter shortcuts
// ---------------------------------------------------------------------------

class _CartButton extends StatelessWidget {
  const _CartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (count, total) = context.select<OrderProvider, (int, String)>(
      (order) => (order.itemCount, order.formattedTotal),
    );

    return _ActionButton(
      icon: Icons.shopping_cart_outlined,
      label: count == 0
          ? 'Cart is empty'
          : 'Cart · ${count == 1 ? '1 item' : '$count items'}',
      sublabel: count > 0 ? '$total so far' : null,
      onTap: onTap,
    );
  }
}

/// The primary action button shared by the Home counter shortcuts.
///
/// One definition so the Cart, New order, Scan, and Symptom guide buttons
/// cannot drift apart. [sublabel] adds a second, smaller line under [label]
/// (used by the Cart to show the running total).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sublabel,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = sublabel;

    return SizedBox(
      height: 42,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.brandGreenSurface,
          foregroundColor: AppColors.brandGreen,
          side: const BorderSide(color: AppColors.brandGreenSurfaceBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: detail == null
                  ? Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
