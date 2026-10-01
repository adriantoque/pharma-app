import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../search/data/models/medicine_model.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../widgets/expiry_sheet.dart';

/// Reached from the Home tile "Expiring Meds".
///
/// Nested under the Home branch, so the bottom bar keeps Home selected and the
/// back arrow returns to the tile the user actually tapped from.
///
/// Lists only the lines that have a date, soonest first, and separates the ones
/// already past it. Starts empty on purpose: the records contain no expiry data
/// at all, so a list pretending otherwise would be showing nothing and calling
/// it a result. The empty body is an instruction -- record a date from a line
/// here, or from the row on the inventory screen.
class ExpiringMedsScreen extends StatelessWidget {
  const ExpiringMedsScreen({super.key});

  /// Soonest first, with a lapsed line first of all.
  ///
  /// Ties broken by name so a list of everything expiring on the same day is in
  /// a stable order rather than reshuffling between rebuilds.
  static int _byExpiry(MedicineModel a, MedicineModel b) {
    final byDate = a.expiryDate!.compareTo(b.expiryDate!);
    return byDate != 0
        ? byDate
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watched: a date recorded on this screen, or on the inventory screen, has
    // to move the list.
    final catalogue = context.watch<MedicineProvider>();

    final dated = catalogue
        .all()
        .where((medicine) => medicine.expiryDate != null)
        .toList()
      ..sort(_byExpiry);

    final expired = dated.where((medicine) => medicine.isExpired).toList();

    // The window the middle section covers, in days. Three months is a typical
    // reorder horizon and is short enough that the list stays something to read.
    const soonDays = 90;
    final soon = <MedicineModel>[];
    final later = <MedicineModel>[];
    for (final medicine in dated) {
      if (medicine.isExpired) continue;
      if (medicine.daysUntilExpiry! <= soonDays) {
        soon.add(medicine);
      } else {
        later.add(medicine);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Expiring Meds'), centerTitle: true),
      body: switch ((catalogue.error, catalogue.isLoading)) {
        (final String message, _) => _Body(
            icon: Icons.cloud_off_outlined,
            title: 'The price list did not load',
            detail: message,
          ),
        (_, true) => const Center(child: CircularProgressIndicator()),
        _ when dated.isEmpty => const _Body(
            icon: Icons.event_busy_outlined,
            title: 'No expiry dates recorded',
            detail: 'Expiry dates are entered by hand: open a product from '
                'Inventory and set the date its lot expires. Nothing has been '
                'recorded yet.',
          ),
        _ => ListView(
            children: [
              if (expired.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Already expired',
                  count: expired.length,
                  colour: theme.colorScheme.error,
                ),
                for (final medicine in expired)
                  _ExpiryRow(
                    medicine: medicine,
                    onTap: () => _edit(context, medicine),
                  ),
              ],
              if (soon.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Expiring within $soonDays days',
                  count: soon.length,
                  colour: theme.colorScheme.error,
                ),
                for (final medicine in soon)
                  _ExpiryRow(
                    medicine: medicine,
                    onTap: () => _edit(context, medicine),
                  ),
              ],
              if (later.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Later',
                  count: later.length,
                  colour: theme.colorScheme.onSurfaceVariant,
                ),
                for (final medicine in later)
                  _ExpiryRow(
                    medicine: medicine,
                    onTap: () => _edit(context, medicine),
                  ),
              ],
              // Room for the last row to clear the floating bar in a list that
              // is scrolled to the bottom.
              const SizedBox(height: 24),
            ],
          ),
      },
    );
  }

  Future<void> _edit(BuildContext context, MedicineModel medicine) {
    return showExpirySheet(context, medicine: medicine);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.colour,
  });

  final String title;
  final int count;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        '$title ($count)',
        style: theme.textTheme.labelLarge?.copyWith(color: colour),
      ),
    );
  }
}

class _ExpiryRow extends StatelessWidget {
  const _ExpiryRow({required this.medicine, required this.onTap});

  final MedicineModel medicine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // `daysUntilExpiry` is null for a line that has already lapsed, and that is
    // the one line whose wording matters most, so the lapsed case is settled
    // first and the number is only read once it is known to mean something.
    final days = medicine.daysUntilExpiry;

    // Wording by band rather than a bare day count, because "3 days" and "3
    // months" are not the same urgency and a single number flattens that.
    final (label, colour) = switch (medicine.isExpired) {
      true => ('Expired', theme.colorScheme.error),
      false => switch (days!) {
          0 => ('Expires today', theme.colorScheme.error),
          <= 30 => ('Expires in $days days', theme.colorScheme.error),
          <= 90 => ('Expires in $days days', theme.colorScheme.tertiary),
          _ => ('Expires in $days days', theme.colorScheme.onSurfaceVariant),
        },
    };

    return ListTile(
      onTap: onTap,
      title: Text(medicine.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(color: colour),
      ),
      trailing: Text(
        MaterialLocalizations.of(context).formatMediumDate(medicine.expiryDate!),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
