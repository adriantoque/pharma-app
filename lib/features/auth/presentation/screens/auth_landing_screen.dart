import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_bottom_sheet.dart';

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  /// Opens the sign-in sheet in [mode], with a title that tells the user which
  /// account they are being asked for.
  void _openSheet(
    BuildContext context, {
    required AuthSheetMode mode,
    required String title,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (context) => AuthBottomSheet(mode: mode, title: title),
    );
  }

  Future<void> _continueAsGuest(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    // Navigation is left entirely to the router's redirect, exactly as a
    // successful sign-in does: entering offline mode flips AuthStatus, and the
    // redirect sends the user to the home tab on its own.
    await auth.enterOfflineMode();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isBusy = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: scheme.surface,
      // The button column is fixed-height and the screen has no natural scroll
      // room on a short device, so the body is made scrollable and given the
      // viewport as a floor.
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
                          color: AppColors.teal,
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
                        onPressed: () => _openSheet(
                          context,
                          mode: AuthSheetMode.login,
                          title: 'Admin sign in',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _RoleButton(
                        icon: Icons.badge_outlined,
                        label: 'Sign in as Staff',
                        enabled: !isBusy,
                        filled: false,
                        onPressed: () => _openSheet(
                          context,
                          mode: AuthSheetMode.login,
                          title: 'Staff sign in',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _RoleButton(
                        icon: Icons.person_outline,
                        label: 'Continue as Guest',
                        enabled: !isBusy,
                        filled: false,
                        onPressed: () => _continueAsGuest(context),
                      ),
                      const SizedBox(height: 24),
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

/// One of the three landing buttons.
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
          backgroundColor: AppColors.tealSurface,
          foregroundColor: AppColors.teal,
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
        backgroundColor: AppColors.tealSurface,
        foregroundColor: AppColors.teal,
        side: const BorderSide(color: AppColors.tealSurfaceBorder),
        textStyle: textStyle,
        shape: shape,
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}