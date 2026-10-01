import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    // Captured before any await so the messenger is never resolved from a
    // context that has been unmounted.
    final messenger = ScaffoldMessenger.of(context);

    // useRootNavigator is false and the dialog pops itself through
    // [dialogContext]. This screen lives inside a StatefulShellRoute branch,
    // which has its own nested navigator: had the dialog been pushed on the
    // root (the showDialog default) and popped via Navigator.of(context) — the
    // branch — the two would disagree and go_router would be left holding an
    // empty route configuration.
    final shouldLogout = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
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

    if (shouldLogout != true) return;

    final success = await auth.logout();
    // The router's redirect sends the user back to the login screen once the
    // auth state flips, so no manual navigation is needed here.
    if (!success && auth.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(auth.error!)));
    }
  }

  Future<void> _confirmExitOffline(BuildContext context) async {
    final auth = context.read<AuthProvider>();

    final shouldExit = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit offline mode?'),
        content: const Text(
          'Your on-device changes will remain on this phone, '
          'but you will need to sign in to sync them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (shouldExit != true) return;
    // The router's redirect sends the user to the login screen.
    await auth.exitOfflineMode();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isOffline = auth.isOffline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        // Profile is now a pushed page (no longer a tab root), so its title
        // is lead-aligned rather than centred.
        actions: [
          IconButton(
            tooltip: isOffline ? 'Exit offline mode' : 'Sign out',
            onPressed: auth.isLoading
                ? null
                : () => isOffline
                    ? _confirmExitOffline(context)
                    : _confirmLogout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CircleAvatar(
            radius: 36,
            child: Icon(
              isOffline ? Icons.cloud_off : Icons.person,
              size: 40,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isOffline ? 'Offline mode' : (user?.name ?? 'Signed in'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          if (isOffline) ...[
            const SizedBox(height: 4),
            Text(
              'Changes are saved on this device only.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (user?.email != null) ...[
            const SizedBox(height: 4),
            Text(
              user!.email!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(isOffline ? 'Exit offline mode' : 'Sign out'),
            onTap: auth.isLoading
                ? null
                : () => isOffline
                    ? _confirmExitOffline(context)
                    : _confirmLogout(context),
          ),
        ],
      ),
    );
  }
}
