import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../search/data/models/medicine_model.dart';
import '../../../search/presentation/providers/medicine_provider.dart';

/// Asks for a shelf expiry for [medicine] and records it.
///
/// Returns the date that was recorded, or null if the sheet was dismissed.
///
/// Clearing is a control here for the same reason it is one in the stock sheet:
/// a date that could only be removed by editing the document would be a date that
/// stays wrong once it is wrong. The picker opens on the current date when there
/// is one and on today when there is not, rather than on an arbitrary year, so
/// the field the user has to change is the day and month.
Future<DateTime?> showExpirySheet(
  BuildContext context, {
  required MedicineModel medicine,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (context) => _ExpirySheet(medicine: medicine),
  );
}

class _ExpirySheet extends StatefulWidget {
  const _ExpirySheet({required this.medicine});

  final MedicineModel medicine;

  @override
  State<_ExpirySheet> createState() => _ExpirySheetState();
}

class _ExpirySheetState extends State<_ExpirySheet> {
  late DateTime _date = widget.medicine.expiryDate ?? DateTime.now();

  bool get _clearing => widget.medicine.expiryDate == null;

  void _clear() {
    context.read<MedicineProvider>().setExpiry(widget.medicine, null);
    Navigator.of(context).pop();
  }

  void _save() {
    // Midnight, so the stored date is a date. A time of day carried in from the
    // picker would be a fiction, and would make the same expiry compare as two
    // different days.
    final date = DateTime(_date.year, _date.month, _date.day);
    context.read<MedicineProvider>().setExpiry(widget.medicine, date);
    Navigator.of(context).pop(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wasRecorded = widget.medicine.expiryDate != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.medicine.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Expiry date of the lot on the shelf',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            // Through the localisations rather than a hand-rolled format, so the
            // date reads the way the rest of the app's dates do.
            MaterialLocalizations.of(context).formatMediumDate(_date),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          if (_clearing)
            Text(
              'Not recorded yet',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('expiryPick'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                // A shelf life is not a booking system, so a date before today
                // is allowed: a lot already past its date is exactly the thing
                // this screen exists to surface, and refusing to record it would
                // make the problem invisible.
                firstDate: DateTime(2000),
                lastDate: DateTime(DateTime.now().year + 10),
              );
              if (picked != null) setState(() => _date = picked);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: const Text('Choose a date'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (wasRecorded) ...[
                Expanded(
                  child: TextButton.icon(
                    key: const Key('expiryClear'),
                    onPressed: _clear,
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const Key('expirySave'),
                  onPressed: _save,
                  child: const Text('Save date'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
