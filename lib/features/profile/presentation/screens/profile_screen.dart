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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        // Set per screen rather than in AppBarTheme, so the pushed child pages
        // keep their leading-aligned titles. Safe here despite the Sign out
        // action: AppBar centres on the full toolbar width and only clamps when
        // the title would collide with the trailing widgets.
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: auth.isLoading ? null : () => _confirmLogout(context),
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
              Icons.person,
              size: 40,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.name ?? 'Signed in',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          if (user?.email != null) ...[
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
            title: const Text('Sign out'),
            onTap: auth.isLoading ? null : () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }
}
