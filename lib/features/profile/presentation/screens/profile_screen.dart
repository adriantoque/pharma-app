import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_mode_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Actions (top-level so every sub-widget can call them)
// ---------------------------------------------------------------------------

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
    messenger.showSnackBar(
      SnackBar(content: Text(auth.error ?? 'An unknown error occurred')),
    );
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

/// Placeholder for screens that are not built yet. Replace each call with a
/// real route (e.g. `context.push('/profile/store')`) as screens land.
void _comingSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(label)));
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Nothing here watches the provider: each child below subscribes only to
    // the fields it needs, so this build runs once.
    return Scaffold(
      // Profile is a pushed page (not a tab root), so the title stays
      // lead-aligned rather than centred. Signing out lives at the bottom of
      // the scroll, not here.
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: Center(
          // Keeps the layout tidy on tablets / foldables.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: const [
                _HeaderCard(),
                _OfflineBanner(),
                SizedBox(height: 24),
                _BusinessSection(),
                SizedBox(height: 24),
                _SupportSection(),
                SizedBox(height: 32),
                _SignOutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (name, email, isOffline) = context
        .select<AuthProvider, (String?, String?, bool)>(
          (a) => (a.user?.name, a.user?.email, a.isOffline),
        );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                isOffline ? Icons.cloud_off : Icons.person,
                size: 32,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOffline ? 'Offline mode' : (name ?? 'Signed in'),
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isOffline && email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final isOffline = context.select<AuthProvider, bool>((a) => a.isOffline);
    if (!isOffline) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: colors.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Changes are saved on this device only.',
                  style: TextStyle(color: colors.onTertiaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section + tiles
// ---------------------------------------------------------------------------

class _BusinessSection extends StatelessWidget {
  const _BusinessSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Manage business',
      children: [
        _NavTile(
          icon: Icons.storefront_outlined,
          label: 'Store details',
          onTap: () => _comingSoon(context, 'Store details'),
        ),
        _NavTile(
          icon: Icons.lock_outline,
          label: 'Permissions',
          onTap: () => _comingSoon(context, 'Permissions'),
        ),
        _NavTile(
          icon: Icons.palette_outlined,
          label: 'Appearance',
          onTap: () => context.pushNamed('home-profile-appearance'),
        ),
      ],
    );
  }
}

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeModeProvider>();

    return SwitchListTile(
      secondary: const Icon(Icons.dark_mode_outlined),
      title: const Text('Dark mode'),
      subtitle: const Text('Use a darker color theme'),
      value: themeMode.isDarkMode,
      onChanged: (enabled) async {
        try {
          await themeMode.setDarkMode(enabled);
        } catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save appearance: $error')),
          );
        }
      },
    );
  }
}

class _SupportSection extends StatelessWidget {
  const _SupportSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Support',
      children: [
        _NavTile(
          icon: Icons.help_outline,
          label: 'Help and support',
          onTap: () => _comingSoon(context, 'Help and support'),
        ),
        _AboutTile(onTap: () => _comingSoon(context, 'About')),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias, // clips ink ripples to the corners
          color: theme.colorScheme.surfaceContainerLow,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(height: 1, indent: 56),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String label;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailingText = this.trailingText;

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: trailingText != null
          ? Text(
              trailingText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// "About" row that shows the installed app version. The lookup runs once in
/// [initState], not on every rebuild.
class _AboutTile extends StatefulWidget {
  const _AboutTile({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AboutTile> createState() => _AboutTileState();
}

class _AboutTileState extends State<_AboutTile> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = 'v${info.version}');
    } catch (_) {
      // Leave the trailing chevron if the lookup fails. Under flutter_test
      // there is no platform channel behind the plugin at all, so this is the
      // path every test takes.
    }
  }

  @override
  Widget build(BuildContext context) {
    return _NavTile(
      icon: Icons.info_outline,
      label: 'About',
      trailingText: _version,
      onTap: widget.onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Sign out
// ---------------------------------------------------------------------------

class _SignOutButton extends StatelessWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final (isOffline, isLoading) = context.select<AuthProvider, (bool, bool)>(
      (a) => (a.isOffline, a.isLoading),
    );

    return OutlinedButton.icon(
      onPressed: isLoading
          ? null
          : () => isOffline
                ? _confirmExitOffline(context)
                : _confirmLogout(context),
      icon: isLoading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout),
      label: Text(isOffline ? 'Exit offline mode' : 'Sign out'),
      style: OutlinedButton.styleFrom(
        foregroundColor: error,
        side: BorderSide(color: error),
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}
