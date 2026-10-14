import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/medicine_information.dart';
import '../../data/models/medicine_model.dart';
import '../providers/medicine_provider.dart';

enum _MedicineFilter { all, lowStock, inStock }

/// Browsable, searchable view of every medicine in the live catalogue.
///
/// Package variants are grouped under their shared medicine name, with quick
/// stock filters and the detailed information kept available from every row.
class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _MedicineFilter _filter = _MedicineFilter.all;

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
    final searchedMedicines = _query.trim().isEmpty
        ? catalogue.all()
        : catalogue.search(_query);
    final medicines = searchedMedicines.where((medicine) {
      return switch (_filter) {
        _MedicineFilter.all => true,
        _MedicineFilter.lowStock => medicine.isLowStock,
        _MedicineFilter.inStock =>
          medicine.stock != null && medicine.stock! > 0,
      };
    }).toList();
    final groups = _groupMedicines(medicines);

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
                '${groups.length} ${groups.length == 1 ? 'medicine' : 'medicines'}'
                '${medicines.length != groups.length ? ' · ${medicines.length} packages' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _MedicineFilterChip(
                  label: 'All',
                  selected: _filter == _MedicineFilter.all,
                  onSelected: () =>
                      setState(() => _filter = _MedicineFilter.all),
                ),
                const SizedBox(width: 8),
                _MedicineFilterChip(
                  label: 'Low stock',
                  selected: _filter == _MedicineFilter.lowStock,
                  onSelected: () =>
                      setState(() => _filter = _MedicineFilter.lowStock),
                ),
                const SizedBox(width: 8),
                _MedicineFilterChip(
                  label: 'In stock',
                  selected: _filter == _MedicineFilter.inStock,
                  onSelected: () =>
                      setState(() => _filter = _MedicineFilter.inStock),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: switch ((catalogue.error, catalogue.isLoading, groups)) {
              (final String message, _, _) => _MedicineError(
                message: message,
                onDismiss: catalogue.clearError,
              ),
              (_, true, _) => const Center(child: CircularProgressIndicator()),
              (_, _, final Map<String, List<MedicineModel>> items)
                  when items.isEmpty =>
                _MedicineEmpty(
                  query: _query,
                  hasFilter: _filter != _MedicineFilter.all,
                ),
              _ => ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final group = groups.entries.elementAt(index);
                  return _MedicineGroupTile(
                    name: group.key,
                    medicines: group.value,
                  );
                },
              ),
            },
          ),
        ],
      ),
    );
  }
}

Map<String, List<MedicineModel>> _groupMedicines(
  Iterable<MedicineModel> medicines,
) {
  final groups = <String, List<MedicineModel>>{};
  for (final medicine in medicines) {
    groups.putIfAbsent(medicine.name, () => []).add(medicine);
  }
  return groups;
}

class _MedicineFilterChip extends StatelessWidget {
  const _MedicineFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    showCheckmark: false,
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _MedicineGroupTile extends StatelessWidget {
  const _MedicineGroupTile({required this.name, required this.medicines});

  final String name;
  final List<MedicineModel> medicines;

  void _showDetails(BuildContext context, MedicineModel medicine) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MedicineDetailsSheet(medicine: medicine),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medication_outlined,
                    size: 21,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (medicines.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text(
                      '${medicines.length} options',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < medicines.length; index++) ...[
              if (index > 0)
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
              _MedicinePackageRow(
                medicine: medicines[index],
                onTap: () => _showDetails(context, medicines[index]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MedicinePackageRow extends StatelessWidget {
  const _MedicinePackageRow({required this.medicine, required this.onTap});

  final MedicineModel medicine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final packageType = medicine.packageType ?? 'Standard unit';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    packageType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    medicine.formattedPrice,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StockBadge(medicine: medicine),
          ],
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.medicine});

  final MedicineModel medicine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnavailable = medicine.isOutOfStock;
    final isLow = medicine.isLowStock;
    final background = isUnavailable
        ? theme.colorScheme.errorContainer
        : isLow
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.secondaryContainer;
    final foreground = isUnavailable
        ? theme.colorScheme.onErrorContainer
        : isLow
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onSecondaryContainer;
    final label = switch (medicine.stock) {
      null => 'Not counted',
      0 => 'Out of stock',
      final int count => '$count in stock${isLow ? ' · Low' : ''}',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
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
    final catalogue = context.watch<MedicineProvider>();
    final matchingMedicine = catalogue
        .all()
        .where((item) => item == medicine)
        .firstOrNull;
    final currentMedicine = matchingMedicine == null
        ? medicine
        : matchingMedicine.copyWith(
            usageIndication:
                matchingMedicine.usageIndication ?? medicine.usageIndication,
          );
    final expiry = currentMedicine.expiryDate;
    final information = MedicineInformation.forName(currentMedicine.name);
    final purpose = currentMedicine.usageIndication ?? information?.purpose;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Medicine details',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close medicine information',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.medication_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          currentMedicine.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              currentMedicine.formattedPrice,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Stock',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _StockBadge(medicine: currentMedicine),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(color: theme.colorScheme.outlineVariant),
                  if (currentMedicine.packageType case final packageType?)
                    _MedicineInfoRow(
                      label: 'Package / unit',
                      value: packageType,
                    ),
                  _MedicineInfoRow(
                    label: 'Type',
                    value: information?.type ?? 'Information not available',
                  ),
                  _MedicineInfoRow(
                    label: 'Usage / indication',
                    value: purpose ?? 'Purpose information is not recorded for this medicine.',
                  ),
                  _MedicineInfoRow(
                    label: 'Expiry date',
                    value: expiry == null
                        ? 'Not recorded'
                        : MaterialLocalizations.of(context)
                              .formatMediumDate(expiry),
                  ),
                  if (currentMedicine.isExpired)
                    Text(
                      'This medicine is expired',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (currentMedicine.genericKey case final genericKey?)
                    _MedicineInfoRow(label: 'Generic name', value: genericKey),
                  if (currentMedicine.aliases.isNotEmpty)
                    _MedicineInfoRow(
                      label: 'Also searched as',
                      value: currentMedicine.aliases.join(', '),
                    ),
                  if (purpose == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Usage information is not recorded for this medicine.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.55,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'General information only. Check the product label and ask a '
                      'pharmacist for advice. Dosage is not provided here.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _updateStock(context, currentMedicine),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Update stock'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStock(
    BuildContext context,
    MedicineModel medicine,
  ) async {
    var stockInput = medicine.stock?.toString() ?? '';
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<(bool, int?)>(
      context: context,
      builder: (dialogContext) {
        String? validationError;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Update stock'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enter the current quantity for ${medicine.name}.'),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: stockInput,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => stockInput = value,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    errorText: validationError,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, (true, null)),
                child: const Text('Not counted'),
              ),
              FilledButton(
                onPressed: () {
                  final value = int.tryParse(stockInput.trim());
                  if (value == null) {
                    setDialogState(
                      () => validationError = 'Enter a stock quantity.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, (true, value));
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !context.mounted) return;
    final catalogue = context.read<MedicineProvider>();
    await catalogue.setStock(medicine, result.$2);
    if (!context.mounted) return;
    if (catalogue.error case final String message) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Stock updated')));
    }
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
  const _MedicineEmpty({required this.query, required this.hasFilter});

  final String query;
  final bool hasFilter;

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
              hasQuery
                  ? Icons.search_off_outlined
                  : hasFilter
                  ? Icons.filter_alt_off_outlined
                  : Icons.medication_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? 'No medicines match "$query"'
                  : hasFilter
                  ? 'No medicines match this stock filter'
                  : 'No medicines yet',
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
