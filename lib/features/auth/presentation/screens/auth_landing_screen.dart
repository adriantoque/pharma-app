import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_bottom_sheet.dart';

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

  Future<void> _signInWithGoogle(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await auth.signInWithGoogle();
    if (!context.mounted) return;
    if (!success && auth.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(auth.error ?? 'An unknown error occurred')));
    }
  }

  Future<void> _continueOffline(BuildContext context) async {
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
      // viewport as a floor: the two Spacers still split the slack when there is
      // any, and the column is allowed to exceed the viewport when there is not,
      // rather than overflowing and throwing. LayoutBuilder is what supplies that
      // height -- a plain `minHeight: double.infinity` would be an unbounded
      // constraint and the IntrinsicHeight below would reject it.
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
                      FilledButton(
                        onPressed: isBusy
                            ? null
                            : () => _openSheet(context, AuthSheetMode.login),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppColors.tealSurface,
                          foregroundColor: AppColors.teal,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text('Login'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: isBusy
                            ? null
                            : () => _openSheet(context, AuthSheetMode.signup),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppColors.tealSurface,
                          foregroundColor: AppColors.teal,
                          side: const BorderSide(
                            color: AppColors.tealSurfaceBorder,
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text('Signup'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: isBusy
                            ? null
                            : () => _signInWithGoogle(context),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: scheme.surface,
                          foregroundColor: AppColors.teal,
                          elevation: 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: AppColors.tealSurfaceBorder,
                            ),
                          ),
                        ),
                        icon: isBusy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.g_mobiledata, size: 28),
                        label: Text(
                          isBusy ? 'Signing in…' : 'Continue with Google',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: isBusy
                            ? null
                            : () => _continueOffline(context),
                        icon: const Icon(Icons.cloud_off_outlined, size: 18),
                        label: const Text(
                          'Continue offline',
                          style: TextStyle(color: AppColors.teal, fontSize: 14),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
