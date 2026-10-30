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
/// Two doors out of the signed-out state: Login and Sign Up, both opening the
/// shared [AuthBottomSheet] in the matching mode. A third tap -- Continue
/// Offline -- lands on the regular app with no server behind it.
///
/// There is no role picker here. Which workspace a person reaches is decided
/// after the backend answers: the profile in `users/{uid}` carries the role,
/// and the router's redirect sends an admin to the admin workspace and staff
/// to the shell. Asking for the role up front only duplicated that check.
class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  void _openSheet(BuildContext context, AuthSheetMode mode) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (context) => AuthBottomSheet(mode: mode),
    );
  }

  Future<void> _continueOffline(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final hasPin = await auth.hasOfflinePin;
    if (!context.mounted) return;
    // Offline mode starts only once the PIN is set or proven, so the pad is
    // pushed first and its own success path calls enterOfflineMode. The
    // router's redirect then lands the user on the home tab, exactly as a
    // successful sign-in does.
    context.pushNamed(hasPin ? 'offline-lock' : 'offline-pin');
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
                        icon: Icons.login,
                        label: 'Login',
                        enabled: !isBusy,
                        filled: true,
                        onPressed: () =>
                            _openSheet(context, AuthSheetMode.login),
                      ),
                      const SizedBox(height: 12),
                      _RoleButton(
                        icon: Icons.person_add_alt_1_outlined,
                        label: 'Sign Up',
                        enabled: !isBusy,
                        filled: false,
                        onPressed: () =>
                            _openSheet(context, AuthSheetMode.signup),
                      ),
                      const SizedBox(height: 20),
                      _RoleButton(
                        icon: Icons.cloud_off_outlined,
                        label: 'Continue Offline',
                        enabled: !isBusy,
                        filled: false,
                        onPressed: () => _continueOffline(context),
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
/// Filled for the primary action and outlined for the rest, so the eye lands on
/// Login first without the others looking disabled.
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