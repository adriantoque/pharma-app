import 'package:flutter/material.dart';

/// A titled group of setting rows, in a card.
///
/// The settings screen reads as iOS-style groups rather than one long form:
/// each group is one concern, named, so an admin scanning for the expiry rule
/// does not read past the store's phone number to find it.
///
/// Follows the admin dashboard's card language exactly -- zero elevation on
/// `surfaceContainerLow`, an anti-aliased clip so the first and last row's
/// ink stay inside the corners.
class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({super.key, required this.title, required this.rows});

  /// The group's name, in the same style as the dashboard's section headers.
  final String title;

  /// The rows. A divider is drawn between each pair, inset past the icon so
  /// it does not cut through it.
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                // No divider before the first row or after the last: the
                // card's edge is already the boundary there.
                if (i > 0)
                  // Inset past the 44px icon tile plus its padding, the same
                  // indent the activity list uses under its avatars.
                  const Divider(height: 1, indent: 76, endIndent: 16),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
