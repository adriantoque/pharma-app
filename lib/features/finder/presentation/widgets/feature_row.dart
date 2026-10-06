import 'package:flutter/material.dart';

import '../../data/models/feature_entry.dart';

/// The icon key used when [FeatureEntry.iconKey] is null or unrecognised.
///
/// A generic icon rather than no icon, because a row with no leading widget
/// shifts its text left and no longer lines up with its neighbours. A missing
/// icon that misaligns the list is a layout bug; a generic icon that does not
/// is not.
const IconData _fallback = Icons.widgets_outlined;

const Map<String, IconData> _icons = {
  'search': Icons.search,
  'inventory': Icons.inventory_2_outlined,
  'expiring': Icons.event_busy_outlined,
  'orders': Icons.receipt_long_outlined,
  'sale': Icons.point_of_sale_outlined,
  'reports': Icons.bar_chart_outlined,
  'scan': Icons.document_scanner_outlined,
  'notifications': Icons.notifications_outlined,
  'profile': Icons.person_outline,
};

/// The keys [iconFor] recognises.
///
/// Public so a test can assert the catalogue contains no typo that would
/// silently fall back to [_fallback]. That class of bug is invisible at runtime
/// -- the row renders, it just wears the wrong icon -- and is only caught by a
/// user asking why Inventory and Reports have the same picture.
Set<String> get knownIconKeys => _icons.keys.toSet();

IconData iconFor(String? key) => _icons[key] ?? _fallback;

/// One result in the feature finder.
class FeatureRow extends StatelessWidget {
  const FeatureRow({super.key, required this.entry, required this.onTap});

  final FeatureEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(iconFor(entry.iconKey), color: theme.colorScheme.primary),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: entry.subtitle == null
          ? null
          : Text(
              entry.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      // The section on the right rather than as a header, which keeps the list
      // flat. If grouping is added later this moves into a header and this
      // trailing goes away.
      trailing: entry.parent == null
          ? null
          : Text(
              entry.parent!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
      onTap: onTap,
    );
  }
}
