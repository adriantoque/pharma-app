import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/medicine_information.dart';
import '../../data/models/medicine_model.dart';
import '../providers/medicine_provider.dart';

/// Browsable, searchable view of every medicine in the live catalogue.
///
/// Stock counting stays in Inventory; this tab is the simple product list
/// staff can use to look up a medicine and its current price.
class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateQuery(String value) {
    setState(() => _query = value);
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = context.watch<MedicineProvider>();
    final theme = Theme.of(context);
    final medicines = _query.trim().isEmpty
        ? catalogue.all()
        : catalogue.search(_query);

    return Scaffold(
      appBar: AppBar(title: const Text('Medicine')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _updateQuery,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Search medicines',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearQuery,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _query.trim().isEmpty
                    ? '${catalogue.all().length} medicines'
                    : '${medicines.length} matching medicines',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: switch ((catalogue.error, catalogue.isLoading, medicines)) {
              (final String message, _, _) => _MedicineError(
                message: message,
                onDismiss: catalogue.clearError,
              ),
              (_, true, _) => const Center(child: CircularProgressIndicator()),
              (_, _, final List<MedicineModel> items) when items.isEmpty =>
                _MedicineEmpty(query: _query),
              _ => ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: medicines.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    _MedicineTile(medicine: medicines[index]),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _MedicineTile extends StatelessWidget {
  const _MedicineTile({required this.medicine});

  final MedicineModel medicine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (stockLabel, stockState) = medicine.stockLine;
    final stockColor = switch (stockState) {
      StockState.outOfStock => theme.colorScheme.error,
      StockState.low => const Color(0xFF8A5A00),
      StockState.unknown => theme.colorScheme.outline,
      StockState.available => theme.colorScheme.onSurfaceVariant,
    };

    return Card(
      child: ListTile(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (_) => _MedicineDetailsSheet(medicine: medicine),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.medication_outlined,
            size: 21,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          medicine.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          stockLabel,
          style: theme.textTheme.bodySmall?.copyWith(color: stockColor),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              medicine.formattedPrice,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineDetailsSheet extends StatelessWidget {
  const _MedicineDetailsSheet({required this.medicine});

  final MedicineModel medicine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (stockLabel, _) = medicine.stockLine;
    final expiry = medicine.expiryDate;
    final information = MedicineInformation.forMedicine(medicine);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Medicine information',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Close medicine information',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(medicine.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          _MedicineInfoRow(label: 'Type', value: information.type),
          _MedicineInfoRow(label: 'Common purpose', value: information.purpose),
          if (information.importantNote case final importantNote?)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                importantNote,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          const Divider(height: 24),
          _MedicineInfoRow(label: 'Price', value: medicine.formattedPrice),
          _MedicineInfoRow(label: 'Stock', value: stockLabel),
          _MedicineInfoRow(
            label: 'Expiry date',
            value: expiry == null
                ? 'Not recorded'
                : MaterialLocalizations.of(context).formatMediumDate(expiry),
          ),
          if (medicine.isExpired)
            Text(
              'This medicine is expired',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (medicine.genericKey case final genericKey?)
            _MedicineInfoRow(label: 'Generic name', value: genericKey),
          if (medicine.aliases.isNotEmpty)
            _MedicineInfoRow(
              label: 'Also searched as',
              value: medicine.aliases.join(', '),
            ),
          const SizedBox(height: 12),
          Text(
            'General information only. Products and formulations can vary. '
            'Follow the package label or your prescriber’s instructions, and '
            'ask a pharmacist if you are unsure. No dosage or treatment '
            'recommendation is provided here.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineInfoRow extends StatelessWidget {
  const _MedicineInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _MedicineEmpty extends StatelessWidget {
  const _MedicineEmpty({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = query.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off_outlined : Icons.medication_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery ? 'No medicines match "$query"' : 'No medicines yet',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineError extends StatelessWidget {
  const _MedicineError({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'The medicine list could not be loaded',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onDismiss, child: const Text('Dismiss')),
          ],
        ),
      ),
    );
  }
}
