import 'package:flutter/material.dart';

/// Stand-in body for a feature that has not been built yet.
///
/// Exists so the navigation shell has something real to render. Each screen
/// replaces its own copy when the feature lands, and this can go with the last
/// of them.
class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;

  /// Deliberately not the same string as the navigation label, so a test can
  /// assert on it without also matching the [NavigationBar] entry.
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
