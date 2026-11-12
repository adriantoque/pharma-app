import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/store_settings_model.dart';
import '../providers/store_settings_provider.dart';
import '../widgets/settings_choice_sheet.dart';
import '../widgets/settings_row.dart';
import '../widgets/settings_section_card.dart';
import '../widgets/settings_text_sheet.dart';

/// The store settings screen: the pharmacy's name, its hours, and the two
/// rules the app's alerts are built on.
///
/// Reached from the Admin dashboard's quick actions, and only ever shown to
/// an admin. The provider is registered above the router in `main.dart`
/// rather than built here: the Expiring Meds screen and the dashboard read
/// the expiry window and the threshold from the same instance, so they would
/// otherwise be reading a copy that only exists while this screen does.
///
/// A list of groups, not a form: every row opens a small editor for exactly
/// one thing, the way the contact apps admins already know work. Changes
/// accumulate locally until Save, so a half-done edit is never half-written
/// to Firestore -- and back with unsaved changes asks before throwing them
/// away.
class StoreSettingsScreen extends StatelessWidget {
  const StoreSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Store settings'),
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
      body: const _StoreSettingsBody(),
    );
  }

  /// Confirms and performs sign-out, as the other admin screens do. The
  /// router's redirect sends the user to login the moment auth flips.
  Future<void> _confirmSignOut(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

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
    if (!context.mounted) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.logout();
    if (!success && auth.error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.error ?? 'An unknown error occurred')),
      );
    }
  }
}

class _StoreSettingsBody extends StatefulWidget {
  const _StoreSettingsBody();

  @override
  State<_StoreSettingsBody> createState() => _StoreSettingsBodyState();
}

class _StoreSettingsBodyState extends State<_StoreSettingsBody> {
  @override
  void initState() {
    super.initState();
    // A retry after a stream failure starts a new subscription, which
    // notifies; notifying during the first build is an error, so this waits
    // for the first frame. An already-healthy subscription is left alone --
    // re-subscribing on every visit would blank the screen for nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<StoreSettingsProvider>();
      if (provider.status == StoreSettingsStatus.error) provider.retry();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoreSettingsProvider>();

    return PopScope(
      // A dirty screen does not let the back arrow discard the admin's work
      // silently: the pop is held and a dialog asks.
      canPop: !provider.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmDiscard();
      },
      child: switch (provider.status) {
        StoreSettingsStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        StoreSettingsStatus.error => _ErrorBody(onRetry: provider.retry),
        StoreSettingsStatus.ready => _SettingsList(),
      },
    );
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'Your edits have not been saved. Leaving now will lose them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (discard != true) return;
    if (!mounted) return;

    context.read<StoreSettingsProvider>().discard();
    // A programmatic pop is not blocked by the dirty guard above -- that
    // guard is for the back gesture, whose tap already arrived.
    Navigator.of(context).pop();
  }
}

class _SettingsList extends StatelessWidget {
  const _SettingsList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<StoreSettingsProvider>();
    final settings = provider.settings;
    final saved = provider.saved;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        SettingsSectionCard(
          title: 'Store profile',
          rows: [
            SettingsRow(
              icon: Icons.storefront_outlined,
              title: 'Store name',
              value: settings.name.trim().isEmpty
                  ? 'Not set yet'
                  : settings.name.trim(),
              onTap: () => _editName(context),
            ),
            SettingsRow(
              icon: Icons.place_outlined,
              title: 'Address',
              value: settings.address?.trim().isNotEmpty ?? false
                  ? settings.address!.trim()
                  : 'Not set yet',
              onTap: () => _editAddress(context),
            ),
            SettingsRow(
              icon: Icons.phone_outlined,
              title: 'Phone',
              value: settings.phone?.trim().isNotEmpty ?? false
                  ? settings.phone!.trim()
                  : 'Not set yet',
              onTap: () => _editPhone(context),
            ),
          ],
        ),

        const SizedBox(height: 24),

        SettingsSectionCard(
          title: 'Business hours',
          rows: [
            SettingsRow(
              icon: Icons.wb_sunny_outlined,
              title: 'Opens at',
              value: StoreSettingsModel.formatMinutes(settings.openMinutes),
              onTap: () => _editOpen(context),
            ),
            SettingsRow(
              icon: Icons.nightlight_outlined,
              title: 'Closes at',
              value: StoreSettingsModel.formatMinutes(settings.closeMinutes),
              onTap: () => _editClose(context),
            ),
          ],
        ),

        const SizedBox(height: 24),

        SettingsSectionCard(
          title: 'Stock & expiry rules',
          rows: [
            SettingsRow(
              icon: Icons.inventory_2_outlined,
              title: 'Low-stock threshold',
              value: '${settings.lowStockThreshold} items',
              onTap: () => _editThreshold(context),
            ),
            SettingsRow(
              icon: Icons.event_busy_outlined,
              title: 'Expiry warning',
              value: '${settings.expiryWarningDays} days',
              onTap: () => _editExpiryWindow(context),
            ),
            SettingsRow(
              icon: Icons.local_shipping_outlined,
              title: 'Reorder coverage',
              value: '${settings.reorderCoverageDays} days',
              onTap: () => _editCoverage(context),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // The Save button only exists when there is something to save: a
        // button that is always there but does nothing most of the time
        // invites a tap that writes nothing and reads as a failure.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: provider.isDirty || provider.isSaving
              ? Column(
                  children: [
                    FilledButton(
                      onPressed: provider.isSaving
                          ? null
                          : () => _save(context),
                      child: provider.isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save changes'),
                    ),
                    const SizedBox(height: 16),
                  ],
                )
              : const SizedBox.shrink(),
        ),

        Center(
          child: Text(
            saved?.updatedAt == null
                ? 'Not saved yet -- the app is running on defaults.'
                : 'Last updated '
                    '${_formatDate(saved!.updatedAt!)}'
                    '${saved.updatedBy == null ? '' : ' by ${saved.updatedBy}'}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  // ── Editors ──────────────────────────────────────────────────────────────
  //
  // Each opens one small sheet and hands the result to the provider. Nothing
  // writes to Firestore here: Save does that, once, for the whole set.

  Future<void> _editName(BuildContext context) async {
    final provider = context.read<StoreSettingsProvider>();
    final value = await showSettingsTextSheet(
      context,
      title: 'Store name',
      initialValue: provider.settings.name,
      helper: 'Shown on reports and exports.',
      validate: (text) =>
          text.trim().isEmpty ? 'Give the store a name.' : null,
    );
    if (value == null || !context.mounted) return;
    provider.updateName(value);
  }

  Future<void> _editAddress(BuildContext context) async {
    final provider = context.read<StoreSettingsProvider>();
    final value = await showSettingsTextSheet(
      context,
      title: 'Address',
      initialValue: provider.settings.address ?? '',
      helper: 'Optional.',
    );
    if (value == null || !context.mounted) return;
    provider.updateAddress(value);
  }

  Future<void> _editPhone(BuildContext context) async {
    final provider = context.read<StoreSettingsProvider>();
    final value = await showSettingsTextSheet(
      context,
      title: 'Phone',
      initialValue: provider.settings.phone ?? '',
      helper: 'Optional.',
      keyboardType: TextInputType.phone,
    );
    if (value == null || !context.mounted) return;
    provider.updatePhone(value);
  }

  Future<void> _editOpen(BuildContext context) async {
    final provider = context.read<StoreSettingsProvider>();
    final settings = provider.settings;
    final picked = await _pickTime(
      context,
      settings.openMinutes,
      'Opening time',
    );
    if (picked == null || !context.mounted) return;
    // Inline, not on Save: a closing time earlier than the opening time is
    // nonsensical the moment it is on the sheet, and saying so there costs
    // less than discovering it at the Save button.
    if (picked >= settings.closeMinutes) {
      _snack(context, 'Opening time must be before closing time.');
      return;
    }
    provider.updateOpen(picked);
  }

  Future<void> _editClose(BuildContext context) async {
    final provider = context.read<StoreSettingsProvider>();
    final settings = provider.settings;
    final picked = await _pickTime(
      context,
      settings.closeMinutes,
      'Closing time',
    );
    if (picked == null || !context.mounted) return;
    if (picked <= settings.openMinutes) {
      _snack(context, 'Closing time must be after opening time.');
      return;
    }
    provider.updateClose(picked);
  }

  Future<void> _editThreshold(BuildContext context) async {
    final provider = context.read<StoreSettingsProvider>();
    final value = await showSettingsTextSheet(
      context,
      title: 'Low-stock threshold',
      initialValue: provider.settings.lowStockThreshold.toString(),
      helper: 'A line is called low when its stock is at or below this.',
      keyboardType: TextInputType.number,
      validate: (text) {
        final parsed = int.tryParse(text.trim());
        if (parsed == null ||
            parsed < StoreSettingsModel.minLowStockThreshold ||
            parsed > StoreSettingsModel.maxLowStockThreshold) {
          return 'Enter a whole number from '
              '${StoreSettingsModel.minLowStockThreshold} to '
              '${StoreSettingsModel.maxLowStockThreshold}.';
        }
        return null;
      },
    );
    if (value == null || !context.mounted) return;
    provider.updateLowStockThreshold(int.parse(value.trim()));
  }

  Future<void> _editExpiryWindow(BuildContext context) async {
    final provider = context.read<StoreSettingsProvider>();
    final picked = await showSettingsChoiceSheet<int>(
      context,
      title: 'Expiry warning',
      helper: 'How far ahead an expiry date is worth flagging.',
      selected: provider.settings.expiryWarningDays,
      choices: [
        for (final days in StoreSettingsModel.expiryWindowChoices)
          SettingsChoice(days, '$days days'),
      ],
    );
    if (picked == null || !context.mounted) return;
    provider.updateExpiryWarningDays(picked);
  }

  Future<void> _editCoverage(BuildContext context) async {
    final provider = context.read<StoreSettingsProvider>();
    final picked = await showSettingsChoiceSheet<int>(
      context,
      title: 'Reorder coverage',
      helper: 'How many days of demand a reorder target should cover.',
      selected: provider.settings.reorderCoverageDays,
      choices: [
        for (final days in StoreSettingsModel.reorderCoverageChoices)
          SettingsChoice(days, '$days days'),
      ],
    );
    if (picked == null || !context.mounted) return;
    provider.updateReorderCoverageDays(picked);
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save(BuildContext context) async {
    // Captured before the await: the save may outlive the widget, and the
    // messenger keeps working either way.
    final messenger = ScaffoldMessenger.of(context);
    final errorColour = Theme.of(context).colorScheme.error;
    final provider = context.read<StoreSettingsProvider>();

    final ok = await provider.save();
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(provider.saveError ?? 'Could not save the settings.'),
            backgroundColor: errorColour,
          ),
        );
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Settings saved.')));
  }

  // ── Shared ───────────────────────────────────────────────────────────────

  Future<int?> _pickTime(
    BuildContext context,
    int currentMinutes,
    String helpText,
  ) async {
    final current = TimeOfDay(
      hour: currentMinutes ~/ 60,
      minute: currentMinutes % 60,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: helpText,
    );
    if (picked == null) return null;
    return picked.hour * 60 + picked.minute;
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// `Nov 12, 2026`, without pulling in `intl` for one format the app has no
  /// other use for.
  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// What the stream failing looks like. A settings document that cannot be
/// read is not a screen that should sit blank: say what happened, and offer
/// the one action that can fix it.
class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              'The settings did not load',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Check the connection and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

enum _StoreMenuAction { signOut }
