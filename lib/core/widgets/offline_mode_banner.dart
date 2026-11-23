import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

/// Persistent notice that the app is running in offline mode.
///
/// Unlike [OfflineBanner], which only appears when a *connection* is lost, this
/// stays up for the whole offline session. Offline mode is a deliberate user
/// choice, not an outage -- and the pharmacist needs to know that stock counts
/// and orders are being written to local storage only, not to the server.
class OfflineModeBanner extends StatelessWidget {
  const OfflineModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isOffline = context.select<AuthProvider, bool>(
      (provider) => provider.isOffline,
    );
    if (!isOffline) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.tertiaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: scheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline mode. Changes are saved on this device only.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer,
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
