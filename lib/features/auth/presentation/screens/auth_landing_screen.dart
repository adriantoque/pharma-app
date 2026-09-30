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
    // A cancelled account chooser returns false with no error; stay quiet.
    if (!success && auth.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(auth.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isBusy = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      // Explicit, because the theme's scaffold background is transparent so
      // the shell's artwork can show through. This route is outside the shell,
      // so without it there would be nothing behind these buttons and the
      // window background would show instead.
      backgroundColor: scheme.surface,
      body: SafeArea(
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
                backgroundImage: const AssetImage('assets/images/baseIcon.png'),
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
                  side: const BorderSide(color: AppColors.tealSurfaceBorder),
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
                // Disabled while a sign-in is in flight: repeated taps used to
                // queue concurrent Google sign-ins with no visual feedback.
                onPressed: isBusy ? null : () => _signInWithGoogle(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: scheme.surface,
                  foregroundColor: AppColors.teal,
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: AppColors.tealSurfaceBorder),
                  ),
                ),
                icon: isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
            ],
          ),
        ),
      ),
    );
  }
}
