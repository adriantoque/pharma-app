import 'package:flutter/material.dart';

/// One setting on a section card: what it is, what it is set to, and the
/// promise that tapping it opens an editor.
///
/// The whole row is the tap target, not the trailing icon -- a setting is
/// edited by reaching for it, and a pencil-sized target on a counter tablet
/// is a finger-fatigue bug.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  /// What the setting is, shown under an icon tile built like the admin
  /// dashboard's action tiles, so the two screens read as one app.
  final IconData icon;
  final String title;

  /// The current value, or a placeholder such as "Not set yet". A value that
  /// exists is inked in `onSurface`; the placeholder is deliberately dimmer,
  /// so an unset field is findable at a glance.
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSet = value.isNotEmpty && value != 'Not set yet';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSet
                          ? scheme.onSurfaceVariant
                          : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, size: 18, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}
