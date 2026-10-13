import 'package:flutter/material.dart';

/// The store settings screen for administrators.
///
/// Allows the admin to configure store basic information.
/// This is a scaffold that will be expanded in future sprints.
class StoreSettingsScreen extends StatelessWidget {
  const StoreSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store settings'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<_StoreMenuAction>(
            tooltip: 'More',
            onSelected: (action) => switch (action) {
              _StoreMenuAction.signOut => _confirmSignOut(context),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _StoreMenuAction.signOut,
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Sign out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Store settings coming soon'),
            const Text('This feature will be implemented in a future sprint.'),
          ],
        ),
      ),
    );
  }

  /// Shows a sign-out confirmation dialog.
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
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

    if (confirmed != true) return;
  }
}

enum _StoreMenuAction { signOut }