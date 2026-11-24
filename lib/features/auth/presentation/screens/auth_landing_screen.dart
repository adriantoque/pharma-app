import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_bottom_sheet.dart';

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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 8,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'PharmaStaff POS · Cloud & Offline Ready',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.secondary, AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Icon(
                          Icons.local_pharmacy_rounded,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'WELCOME TO',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.secondaryLight,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Wilma Pharmacy's",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontSize: 32,
                          color: scheme.onSurface,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your trusted pharmacy companion for instant counter checkout, OCR box scanning & clinical triage.',
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
                      const SizedBox(height: 10),
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
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
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
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: textStyle,
          shape: shape,
        ),
        icon: Icon(icon),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }

    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: scheme.surfaceContainerLow,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: textStyle,
        shape: shape,
      ),
      icon: Icon(icon),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}