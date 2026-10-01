import 'package:flutter/material.dart';

import '../../features/search/data/sync/sync_status.dart';

/// The one thing the pharmacist has to know about the network at a glance.
///
/// Sits above the navigation bar and stays out of the way when there is nothing to
/// say. Deliberately not an error: losing the connection on a shop floor is routine,
/// and the price list keeps working, so this reports state rather than complaining.
///
/// Two messages, because the difference matters. Offline with nothing waiting says
/// the work is safe; offline with writes outstanding says it is not saved yet. A
/// single "you are offline" line would leave a user closing the app unsure which of
/// those they were in.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.isOffline) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final pending = status.hasPendingChanges;

    return Material(
      // A tonal fill rather than a border: the banner is part of the page rather
      // than an alert laid over it, and it must not shift the panel below it when
      // it appears.
      color: scheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                pending ? Icons.cloud_upload_outlined : Icons.cloud_off_outlined,
                size: 18,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pending
                      ? 'Offline. ${_pendingChanges(status)}'
                      : _showingOldData(status),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// How many changes are waiting, said out loud.
  ///
  /// The count is real rather than an estimate: it comes from the app's own queue
  /// of writes the server has not confirmed, which is what makes it safe to put a
  /// number in front of somebody. One change is "1 change"; a stock count typed
  /// ten minutes ago at the counter is worth naming exactly rather than rounding
  /// to "a few".
  static String _pendingChanges(SyncStatus status) {
    final count = status.pendingWriteCount;
    if (count == 1) {
      return '1 change is saved here and will sync when you reconnect.';
    }
    return '$count changes are saved here and will sync when you reconnect.';
  }

  /// How old the data on screen is, which is what a lost connection actually
  /// means to somebody about to sell from it.
  ///
  /// Measured against the device's clock, because Firestore's Dart client does not
  /// carry the server's read time. A phone with the wrong date will therefore say
  /// something untrue, which is why the wording stays rough: it rounds to the unit
  /// a reader would have used anyway. It is still a far better answer than a
  /// banner that says "offline" and leaves a pharmacist wondering whether the
  /// prices in front of them are this morning's.
  static String _showingOldData(SyncStatus status) {
    final age = status.ageAt(DateTime.now());
    if (age == null) {
      return 'Offline. Showing the price list saved on this device.';
    }

    final freshness = switch (age) {
      final Duration d when d.inMinutes < 1 => 'just now',
      final Duration d when d.inMinutes < 60 => '${d.inMinutes} min ago',
      final Duration d when d.inHours < 24 => '${d.inHours} h ago',
      final Duration d => '${d.inDays} d ago',
    };
    return 'Offline. Showing the price list last updated $freshness.';
  }
}