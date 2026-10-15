import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_bottom_sheet.dart';

/// Brand greens for the landing screen.
///
/// The surface and border are the lighter tint of the shared [AppColors]
/// brand green; the primary value lives there now so the rest of the app can
/// reach the same token.
abstract final class _LandingColors {
  static const Color primary = AppColors.brandGreen;
  static const Color primarySurface = Color(0xFFE2F1ED);
  static const Color primarySurfaceBorder = Color(0xFFA7CFC6);
}

/// The first screen, for a signed-out app.
///
/// Three doors, each leading somewhere different. Admin and Staff are full
/// pages pushed on top of this one, so the back arrow returns here; Offline
/// is a single tap that lands on the regular app with no server behind it.
///
/// The sign-in sheet still exists -- reachable from a fallback link -- for
/// anyone who reaches this screen mid-session and needs to sign in without
/// choosing a door first. Its route through the shared sheet is unchanged.
class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (context) => const AuthBottomSheet(mode: AuthSheetMode.login),
    );
  }

  Future<void> _continueOffline(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    // Navigation is left entirely to the router's redirect, exactly as a
    // successful sign-in does: entering offline mode flips AuthStatus, and
    // the redirect sends the user to the home tab on its own.
    await auth.enterOfflineMode();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isBusy = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Spacer(),
                      Text(
                        'Welcome to',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Wilma\nPharmacy's",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontSize: 40,
                          color: _LandingColors.primary,
                          fontFamily: 'PlayfairDisplay',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: const AssetImage(
                          'assets/images/baseIcon.png',
                        ),
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your trusted pharmacy companion',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      _RoleButton(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Sign in as Admin',
                        enabled: !isBusy,
                        filled: true,
                        onPressed: () => context.pushNamed('admin-login'),
                      ),
                      const SizedBox(height: 12),
                      _RoleButton(
                        icon: Icons.badge_outlined,
                        label: 'Sign in as Staff',
                        enabled: !isBusy,
                        filled: false,
                        onPressed: () => context.pushNamed('staff-login'),
                      ),
                      const SizedBox(height: 12),
                      _RoleButton(
                        icon: Icons.cloud_off_outlined,
                        label: 'Continue Offline',
                        enabled: !isBusy,
                        filled: false,
                        onPressed: () => _continueOffline(context),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: isBusy ? null : () => _openSheet(context),
                        child: Text(
                          'Other sign-in options',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the landing buttons.
///
/// Filled for the primary role and outlined for the rest, so the eye lands on
/// "Sign in as Admin" first without the other two looking disabled.
class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    );
    const textStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );

    if (filled) {
      return FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: _LandingColors.primarySurface,
          foregroundColor: _LandingColors.primary,
          textStyle: textStyle,
          shape: shape,
        ),
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: _LandingColors.primarySurface,
        foregroundColor: _LandingColors.primary,
        side: const BorderSide(color: _LandingColors.primarySurfaceBorder),
        textStyle: textStyle,
        shape: shape,
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}