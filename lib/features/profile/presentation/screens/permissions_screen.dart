import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/domain/user_role.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// What the signed-in account is allowed to do.
///
/// Read-only: it explains the current role rather than changing it. Who may do
/// what is decided by the role, and the roles themselves are set by an admin on
/// the Users screen -- there is nothing to toggle here.
///
/// The capability list comes from the [UserRoleCapabilities] extension, so this
/// screen and the router and the screens that guard an action all read the same
/// rules, and a change to them shows up here without an edit.
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (role, isOffline) = context.select<AuthProvider, (UserRole?, bool)>(
      (auth) => (auth.role, auth.isOffline),
    );

    // An offline guest carries no role; treat an unresolved role the same way.
    final effective = role ?? UserRole.guest;

    final capabilities = <(String, bool)>[
      ('Ring up sales', effective.canSell),
      ('Approve or reject orders', effective.canApproveOrders),
      ('Count and correct stock', effective.canCountStock),
      ('Edit the price list', effective.canEditCatalogue),
      ('View reports', effective.canViewReports),
      ('Manage users', effective.canManageUsers),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          isOffline ? Icons.cloud_off : Icons.badge_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${effective.label} account',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isOffline
                                    ? 'Working offline on this device.'
                                    : 'Role assigned to this account.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Column(
                    children: [
                      for (var i = 0; i < capabilities.length; i++) ...[
                        _CapabilityRow(
                          label: capabilities[i].$1,
                          granted: capabilities[i].$2,
                        ),
                        if (i < capabilities.length - 1)
                          const Divider(height: 1, indent: 56),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'An admin works in a separate workspace and never reaches the '
                  'staff app. Staff and guests share the staff app; a guest is '
                  'a device working without an account and can browse only.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.label, required this.granted});

  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      leading: Icon(
        granted ? Icons.check_circle_outline : Icons.remove_circle_outline,
        color: granted ? scheme.primary : scheme.outline,
      ),
      title: Text(label),
      trailing: Text(
        granted ? 'Allowed' : 'Not allowed',
        style: theme.textTheme.bodySmall?.copyWith(
          color: granted ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
