import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/audit_event.dart';
import '../widgets/activity_row.dart';

/// The Admin workspace: the only screen an administrator sees.
///
/// An admin is held here by the router's redirect and never reaches the
/// staff shell, so there is no "back to app" arrow -- there is nowhere to
/// go back to. The AppBar menu carries sign-out, which is the one way out of
/// the workspace short of closing the app.
///
/// A dashboard rather than a menu: an admin who opens this screen should be
/// able to see the shape of the team at a glance and the last few things that
/// happened, without tapping into each section first. The destinations are
/// still here, under the numbers they act on.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // No leading widget on purpose. An admin is pinned to this subtree;
        // an arrow back to the staff app would open a door the redirect
        // would immediately slam shut.
        automaticallyImplyLeading: false,
        title: const Text('Admin'),
        centerTitle: true,
        actions: [
          PopupMenuButton<_AdminMenuAction>(
            tooltip: 'More',
            onSelected: (action) => switch (action) {
              _AdminMenuAction.signOut => _confirmSignOut(context),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _AdminMenuAction.signOut,
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Sign out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          _GreetingCard(),
          SizedBox(height: 16),
          _StatsRow(),
          SizedBox(height: 24),
          _SectionHeader(title: 'Quick actions'),
          SizedBox(height: 8),
          _QuickActions(),
          SizedBox(height: 24),
          _RecentActivitySection(),
        ],
      ),
    );
  }

  /// Confirms and performs sign-out.
  ///
  /// The router's redirect sends the user to the login screen the moment the
  /// auth state flips, so nothing navigates here.
  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await auth.logout();
    if (!success && auth.error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.error ?? 'An unknown error occurred')),
      );
    }
  }
}

enum _AdminMenuAction { signOut }

// ---------------------------------------------------------------------------
// Greeting
// ---------------------------------------------------------------------------

/// "Welcome back, Maria Santos".
///
/// Reads the signed-in name from [AuthProvider] and falls back to
/// "Administrator" when the profile has none -- a service account created
/// directly in the Firebase Console has no `displayName`.
class _GreetingCard extends StatelessWidget {
  const _GreetingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = context.select<AuthProvider, String?>((a) => a.user?.name);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.onPrimaryContainer.withValues(alpha: 0.15),
              child: Icon(
                Icons.admin_panel_settings,
                color: scheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome back,',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name ?? 'Administrator',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
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

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

/// Two live figures: how many people are on the team, and how many of them
/// can administer it.
///
/// A [StreamBuilder] rather than a provider of its own: the numbers come from
/// one collection that is already streamed elsewhere, and a whole
/// `ChangeNotifier` to relay two counts would be a subscription to keep alive
/// for no benefit.
class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final repository = context.read<UserRepository>();

    return StreamBuilder<List<UserModel>>(
      stream: repository.watchAll(),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <UserModel>[];
        final activeUsers = users.where((u) => u.active).length;
        final activeAdmins = users
            .where((u) => u.active && u.role == UserRole.admin)
            .length;

        return Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.people_outline,
                value: '$activeUsers',
                label: 'Active user${activeUsers == 1 ? '' : 's'}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.shield_outlined,
                value: '$activeAdmins',
                label: activeAdmins == 1 ? 'Admin' : 'Admins',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions
// ---------------------------------------------------------------------------

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.people_outline,
          title: 'Manage users',
          subtitle: 'Add, edit, deactivate accounts',
          onTap: () => context.pushNamed('admin-users'),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.bar_chart_outlined,
          title: 'Reports',
          subtitle: 'Sales and stock analytics',
          onTap: () => context.pushNamed('admin-reports'),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.storefront_outlined,
          title: 'Store settings',
          subtitle: 'Name, hours, low-stock threshold',
          comingSoon: true,
          onTap: () => context.go('/admin/store-settings'),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'View system alerts and updates',
          onTap: () => context.pushNamed('admin-notifications'),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.article_outlined,
          title: 'Activity log',
          subtitle: 'Who did what, when',
          onTap: () => context.pushNamed('admin-activity'),
        ),
      ],
    );
  }
}

/// One destination row.
///
/// This has a "coming soon" state: the tile visuals indicate completion status
/// while the tap still surfaces appropriate feedback.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
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

  /// Draws the tile with muted appearance when coming soon, full colors when
  /// the destination is available. The tap always runs.
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMuted = comingSoon;

    return Card(
      elevation: isMuted ? 0 : 2,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isMuted
                      ? scheme.surfaceContainerHighest
                      : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isMuted
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
                              color: isMuted
                                  ? scheme.onSurfaceVariant
                                  : null,
                              fontWeight: isMuted
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isMuted) ...[
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
              if (!isMuted)
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

// ---------------------------------------------------------------------------
// Recent activity
// ---------------------------------------------------------------------------

/// The last three audit entries, with a "See all" link.
///
/// Shows three and not five so the section reads as a preview rather than a
/// list -- the full log is a screen of its own (the Activity log), and this
/// section is a pointer to it.
class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repository = context.read<AuditRepository>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Recent activity',
          trailing: TextButton(
            onPressed: () => context.pushNamed('admin-activity'),
            child: const Text('See all'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          child: StreamBuilder<List<AuditEvent>>(
            stream: repository.watchAll(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final events = snapshot.data ?? const <AuditEvent>[];
              if (events.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No activity yet.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final preview = events.take(3).toList();
              return Column(
                children: [
                  for (var i = 0; i < preview.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 60, endIndent: 16),
                    ActivityRow(event: preview[i]),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        ?trailing,
      ],
    );
  }
}