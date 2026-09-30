import 'package:flutter/material.dart';

import 'firebase_bootstrap.dart';

/// Shown instead of the app when Firebase could not be initialised, so the
/// user learns why nothing works rather than staring at a blank screen.
class BootstrapFailureScreen extends StatelessWidget {
  const BootstrapFailureScreen({super.key, required this.result});

  final FirebaseBootstrapResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      // This screen renders from its own MaterialApp, above the splash and
      // outside the shell, so the theme's transparent scaffold background would
      // otherwise leave the window background showing through.
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  result.isUnsupportedPlatform
                      ? Icons.desktop_access_disabled_outlined
                      : Icons.cloud_off_outlined,
                  size: 56,
                  color: scheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  result.isUnsupportedPlatform
                      ? 'Platform not supported'
                      : 'Could not start PharmaGuide',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  result.isUnsupportedPlatform
                      ? 'PharmaGuide currently supports Android and the web. '
                            'Reconfigure Firebase for this platform to enable it.'
                      : 'Firebase failed to initialise. Check your network and '
                            'your Firebase configuration, then restart the app.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (result.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      result.errorMessage!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
