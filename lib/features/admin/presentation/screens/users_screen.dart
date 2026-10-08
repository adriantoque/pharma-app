import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../providers/users_provider.dart';
import '../widgets/user_edit_sheet.dart';

/// The Users screen: everybody on the team, and what an admin can do to them.
///
/// Reached from the Admin tab, and only ever shown to an admin. The provider
/// is built here rather than above the router so its subscription dies with
/// the screen -- an admin who signs out should not leave a live stream behind
/// scoped to the account that just left.
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UsersProvider>(
      create: (ctx) {
        final auth = ctx.read<AuthProvider>();
        return UsersProvider(
          repository: ctx.read<UserRepository>(),
          audit: ctx.read<AuditRepository>(),
          actorUid: auth.user?.id ?? '',
          actorName: auth.user?.name ?? 'Unknown',
        );
      },
      child: const _UsersBody(),
    );
  }
}

class _UsersBody extends StatefulWidget {
  const _UsersBody();

  @override
  State<_UsersBody> createState() => _UsersBodyState();
}

class _UsersBodyState extends State<_UsersBody> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    context.read<UsersProvider>().updateQuery(value);
  }

  void _clearSearch() {
    _controller.clear();
    context.read<UsersProvider>().clearQuery();
  }

  Future<void> _openEdit(UserModel user) => showUserEditSheet(
        context,
        user: user,
      );

  Future<void> _openAdd() => showUserEditSheet(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<UsersProvider>();
    final results = provider.results;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Add user',
            icon: const Icon(Icons.person_add_alt),
            onPressed: provider.isSaving ? null : _openAdd,
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchRow(
            controller: _controller,
            onChanged: _onQueryChanged,
            onClear: _clearSearch,
          ),
          _FilterBar(
            selected: provider.filter,
            counts: provider.counts,
            onSelected: provider.setFilter,
          ),
          Expanded(
            child: switch ((provider.error, provider.isLoading)) {
              (final String message, _) => _Message(
                  icon: Icons.cloud_off_outlined,
                  title: 'Users did not load',
                  detail: message,
                  colour: theme.colorScheme.error,
                ),
              (_, true) => const Center(child: CircularProgressIndicator()),
              _ when provider.users.isEmpty => const _Message(
                  icon: Icons.people_outline,
                  title: 'No users yet',
                  detail: 'Add the first staff account with the button above.',
                ),
              _ when results.isEmpty => _Message(
                  icon: Icons.search_off_outlined,
                  title: 'Nothing matches',
                  detail: provider.query.isEmpty
                      ? 'No user is in this state.'
                      : 'No user matches "${provider.query.trim()}".',
                ),
              _ => ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: results.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) => _UserTile(
                    user: results[index],
                    onEdit: () => _openEdit(results[index]),
                  ),
                ),
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search and filter
// ---------------------------------------------------------------------------

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: 'Search by name, email or role',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear',
                  onPressed: onClear,
                ),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final UsersFilter selected;
  final Map<UsersFilter, int> counts;
  final ValueChanged<UsersFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final filter in UsersFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                showCheckmark: false,
                selected: filter == selected,
                onSelected: (_) => onSelected(filter),
                label: Text('${filter.label} ${counts[filter] ?? 0}'),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User row
// ---------------------------------------------------------------------------

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onEdit});

  final UserModel user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = context.read<UsersProvider>();
    final canDeactivate = provider.canDeactivate(user);

    return ListTile(
      onTap: provider.isSaving ? null : onEdit,
      leading: CircleAvatar(
        backgroundColor: user.active
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        child: Icon(
          user.role == UserRole.admin
              ? Icons.admin_panel_settings_outlined
              : Icons.badge_outlined,
          color: user.active
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.name ?? '(no name)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: user.active ? null : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoleBadge(role: user.role),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          user.email ?? '(no email)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      trailing: PopupMenuButton<_UserAction>(
        enabled: !provider.isSaving,
        tooltip: 'Actions',
        onSelected: (action) => switch (action) {
          _UserAction.edit => onEdit(),
          _UserAction.resetPassword =>
            _resetPassword(context, provider),
          _UserAction.toggleActive =>
            _toggleActive(context, provider, canDeactivate),
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _UserAction.edit,
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 20),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: _UserAction.resetPassword,
            child: Row(
              children: [
                Icon(Icons.lock_reset_outlined, size: 20),
                SizedBox(width: 8),
                Text('Reset password'),
              ],
            ),
          ),
          PopupMenuItem(
            value: _UserAction.toggleActive,
            enabled: canDeactivate || !user.active,
            child: Row(
              children: [
                Icon(
                  user.active
                      ? Icons.person_off_outlined
                      : Icons.person_outline,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(user.active ? 'Deactivate' : 'Reactivate'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(
    BuildContext context,
    UsersProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send password reset?'),
        content: Text(
          'Firebase will email a reset link to ${user.email ?? 'this user'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await provider.sendPasswordReset(user);
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Reset email sent to ${user.email}.'
                : provider.error ?? 'Could not send the reset email.',
          ),
        ),
      );
  }

  Future<void> _toggleActive(
    BuildContext context,
    UsersProvider provider,
    bool canDeactivate,
  ) async {
    if (user.active && !canDeactivate) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'You cannot deactivate this account: it is either your own, '
              'or the last active administrator.',
            ),
          ),
        );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final success = await provider.setActive(user, !user.active);
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${user.name} ${user.active ? 'deactivated' : 'reactivated'}.'
                : provider.error ?? 'Could not update the account.',
          ),
        ),
      );
  }
}

enum _UserAction { edit, resetPassword, toggleActive }

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (background, foreground) = switch (role) {
      UserRole.admin => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      UserRole.staff => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      UserRole.guest => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        role.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / error body
// ---------------------------------------------------------------------------

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    this.colour,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colour ?? theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}