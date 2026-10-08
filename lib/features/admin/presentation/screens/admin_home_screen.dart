import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Admin tab's landing.
///
/// Three destinations, one of them built. The other two are visible but
/// inert -- a greyed row that says "Coming soon" is a smaller surprise than a
/// tile that disappears and reappears between versions.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label — coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _AdminTile(
            icon: Icons.people_outline,
            title: 'Users',
            subtitle: 'Add, edit, deactivate accounts',
            onTap: () => context.pushNamed('admin-users'),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.storefront_outlined,
            title: 'Store Settings',
            subtitle: 'Name, hours, low-stock threshold',
            onTap: () => _comingSoon(context, 'Store Settings'),
            comingSoon: true,
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.article_outlined,
            title: 'Activity Log',
            subtitle: 'Who did what, when',
            onTap: () => _comingSoon(context, 'Activity Log'),
            comingSoon: true,
          ),
        ],
      ),
    );
  }
}

/// One destination row.
///
/// Own copy rather than a share of `DashboardTile`, which was built for a
/// different set of cards: this one has a "coming soon" state that tile does
/// not, and the whole row goes grey for it. Nine lines of styling is cheaper
/// than a flag on a widget used in a dozen other places.
class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.comingSoon = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Draws the row muted and drops the chevron. The tap still runs, which is
  /// what surfaces the "coming soon" snackbar -- the tile is not disabled,
  /// it just does not claim to be finished.
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = comingSoon;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: muted
                      ? scheme.surfaceContainerHighest
                      : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: muted
                      ? scheme.onSurfaceVariant
                      : scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: muted ? scheme.onSurfaceVariant : null,
                            ),
                          ),
                        ),
                        if (comingSoon) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Soon',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!comingSoon)
                Icon(
                  Icons.chevron_right,
                  color: scheme.outline,
                ),
            ],
          ),
        ),
      ),
    );
  }
}