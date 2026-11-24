import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../search/data/models/age_guidance.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../scan/presentation/screens/scan_screen.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../../../../core/utils/search_text.dart';
import '../../../symptom_guide/data/models/symptom_entry.dart';
import '../../../symptom_guide/data/repositories/symptom_repository.dart';
import '../../../symptom_guide/presentation/widgets/safety_banner.dart';
import '../widgets/pos_app_bar.dart';

/// The staff POS front view, restored from the `dashboard_screenv2` design.
///
/// One shell, three tabs -- New Sale, Symptoms and Scan SKU -- behind a
/// shared app bar, with the cart reachable through the Cart tab in the staff
/// bar. Everything reads the real providers: the catalogue from
/// [MedicineProvider], the basket from [OrderProvider] and the symptom
/// recommendations from the bundled [StaticSymptomRepository].
///
/// The visual rules (colours, paddings, widget shapes and wording) are the
/// committed ones; only the data behind them changed. Prices print in pesos
/// because the catalogue is priced in centavos, and Tax (5%) is display-only:
/// the order itself is still saved at the goods subtotal, which is what the
/// rest of the app reports.

/// The POS accent colour the design seeds its whole theme from.
const Color _posPrimary = AppColors.secondary;

/// Adds one more of [medicine] to the order, the way the design's
/// `_addToCart` did: the line goes into the provider and a short floating
/// snackbar confirms it. An item the shelf cannot supply is reported instead
/// of being silently swallowed.
void _addToOrder(
  BuildContext context,
  OrderProvider order,
  MedicineModel medicine,
) {
  if (OrderProvider.capFor(medicine) < OrderProvider.minQuantity) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nothing left on the shelf for this item'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  _showQuantityDialog(context, order, medicine);
}

/// Shows a dialog to select the quantity of [medicine] to add to the order.
/// The dialog includes a stepper to adjust the amount, and confirms the
/// selection before adding to the cart.
void _showQuantityDialog(
  BuildContext context,
  OrderProvider order,
  MedicineModel medicine,
) {
  showDialog(
    context: context,
    builder: (dialogContext) =>
        _AddToCartDialog(order: order, medicine: medicine),
  );
}

/// The "Add to Cart" dialog: a stepper plus Cancel / Add actions.
///
/// Stepping (+/-) only mutates local state through setState, so the number on
/// screen updates and the dialog stays open; only the Add action commits the
/// line to the order, confirms with a snackbar and pops the dialog.
class _AddToCartDialog extends StatefulWidget {
  const _AddToCartDialog({required this.order, required this.medicine});

  final OrderProvider order;
  final MedicineModel medicine;

  @override
  State<_AddToCartDialog> createState() => _AddToCartDialogState();
}

class _AddToCartDialogState extends State<_AddToCartDialog> {
  late int _selectedQuantity = OrderProvider.minQuantity;

  int get _maxQuantity => OrderProvider.capFor(widget.medicine);

  void _commit() {
    widget.order.add(widget.medicine, _selectedQuantity);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.medicine.name} added to cart ($_selectedQuantity)',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final medicine = widget.medicine;

    return AlertDialog(
      title: const Text('Add to Cart'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            medicine.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Maximum available: $_maxQuantity',
            style: TextStyle(color: Colors.red.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () {
                  if (_selectedQuantity > OrderProvider.minQuantity) {
                    setState(() {
                      _selectedQuantity--;
                    });
                  }
                },
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '$_selectedQuantity',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  if (_selectedQuantity < _maxQuantity) {
                    setState(() {
                      _selectedQuantity++;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Select quantity to add (1-$_maxQuantity)',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _commit, child: const Text('Add')),
      ],
    );
  }
}

/// TAB 1: NEW SALE -- search, the demographic segmented control, the category
/// chips, then the price list as cards.
class NewSaleCatalogScreen extends StatelessWidget {
  const NewSaleCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();

    return Scaffold(
      appBar: const PosAppBar(),
      body: switch ((provider.error, provider.isLoading, provider.all())) {
        (final String message, _, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message),
          ),
        ),
        (_, true, _) => const Center(child: CircularProgressIndicator()),
        (_, _, final List<MedicineModel> items) => _SaleCatalogTab(
          medicines: items,
        ),
      },
    );
  }
}

class _SaleCatalogTab extends StatefulWidget {
  const _SaleCatalogTab({required this.medicines});

  final List<MedicineModel> medicines;

  @override
  State<_SaleCatalogTab> createState() => _SaleCatalogTabState();
}

class _SaleCatalogTabState extends State<_SaleCatalogTab> {
  AgeGroup _selectedAgeGroup = AgeGroup.both;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  /// The chips are read from the data, so a category the workbook adds shows
  /// up on its own; lines whose category was never recorded only surface
  /// under All.
  List<String> get _categories {
    final names =
        widget.medicines
            .map((medicine) => medicine.category)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    return ['All', ...names];
  }

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrderProvider>();
    final filtered = widget.medicines.where((medicine) {
      if (_selectedAgeGroup != AgeGroup.both &&
          !medicine.isForAge(_selectedAgeGroup)) {
        return false;
      }
      if (_selectedCategory != 'All' &&
          medicine.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty && !medicine.matches(_searchQuery)) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search medicine, generic name...',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              // The demographic-first control from the design, with All so a
              // price list that records no age still shows.
              SegmentedButton<AgeGroup>(
                segments: const [
                  ButtonSegment(
                    value: AgeGroup.both,
                    label: Text('All'),
                    icon: Icon(Icons.people_outline, size: 16),
                  ),
                  ButtonSegment(
                    value: AgeGroup.child,
                    label: Text('Child'),
                    icon: Icon(Icons.child_care, size: 16),
                  ),
                  ButtonSegment(
                    value: AgeGroup.adult,
                    label: Text('Adult'),
                    icon: Icon(Icons.person_outline, size: 16),
                  ),
                ],
                selected: {_selectedAgeGroup},
                onSelectionChanged: (Set<AgeGroup> newSelection) {
                  setState(() {
                    _selectedAgeGroup = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(category),
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                        selectedColor: Theme.of(context).colorScheme.primary
                            .withValues(alpha: 0.22),
                        checkmarkColor: _posPrimary,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No medicines found matching filters.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final medicine = filtered[index];
                    return _PosProductCard(
                      medicine: medicine,
                      onAdd: () => _addToOrder(context, order, medicine),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// TAB 2: SYMPTOM FINDER -- type symptoms, analyze, and see medicines to hand over.
class PosSymptomFinderScreen extends StatefulWidget {
  const PosSymptomFinderScreen({super.key});

  @override
  State<PosSymptomFinderScreen> createState() => _PosSymptomFinderScreenState();
}

class _PosSymptomFinderScreenState extends State<PosSymptomFinderScreen> {
  static const SymptomRepository _repository = StaticSymptomRepository();

  /// Who the medicine is for. Defaults to child to match the previous screen;
  /// `All` is offered too so unlabelled stock is never hidden behind a question.
  AgeGroup _targetAgeGroup = AgeGroup.child;

  /// The symptom ids the staff member has committed so far.
  final Set<String> _selectedSymptomIds = <String>{};

  /// Free-text tokens that could not be matched to any symptom. Kept separate so
  /// the staff member can see what the app did not understand.
  final List<String> _unmatchedTokens = <String>[];

  final TextEditingController _controller = TextEditingController();
  String _currentToken = '';

  static final RegExp _delimiter = RegExp(r'[,\n;]|\s+and\s+');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The symptoms that have been committed, in catalogue order.
  List<SymptomEntry> get _matchedSymptoms {
    final matched =
        _repository
            .all()
            .where((entry) => _selectedSymptomIds.contains(entry.id))
            .toList()
          ..sort(SymptomEntry.compareByName);
    return matched;
  }

  /// Autocomplete suggestions for the token currently being typed.
  List<SymptomEntry> get _suggestions {
    final token = _currentToken.trim();
    if (token.isEmpty) return const <SymptomEntry>[];
    return _repository
        .search(token)
        .where((entry) => !_selectedSymptomIds.contains(entry.id))
        .take(6)
        .toList(growable: false);
  }

  /// Commits a single raw token: either adds the matching symptom or records it
  /// as unmatched. Mutates state; the caller is responsible for setState.
  void _commitToken(String raw) {
    final token = raw.trim();
    if (token.isEmpty) return;

    final matches = _repository.search(token);
    if (matches.isEmpty) {
      if (!_unmatchedTokens.contains(token)) _unmatchedTokens.add(token);
      return;
    }

    // Prefer an exact name/alias match; otherwise take the first suggestion.
    SymptomEntry chosen = matches.first;
    for (final entry in matches) {
      if (entry.searchableNames.any(
        (name) => normaliseForSearch(name) == normaliseForSearch(token),
      )) {
        chosen = entry;
        break;
      }
    }
    _selectedSymptomIds.add(chosen.id);
    _unmatchedTokens.remove(token);
  }

  void _handleInput(String value) {
    final parts = value.split(_delimiter);
    if (parts.length > 1) {
      setState(() {
        for (var i = 0; i < parts.length - 1; i++) {
          _commitToken(parts[i]);
        }
        _currentToken = parts.last;
      });
      _controller.value = TextEditingValue(
        text: parts.last,
        selection: TextSelection.collapsed(offset: parts.last.length),
      );
      return;
    }
    setState(() => _currentToken = value);
  }

  void _commitCurrent() {
    setState(() {
      _commitToken(_controller.text);
      _currentToken = '';
    });
    _controller.clear();
  }

  void _clearAll() {
    setState(() {
      _selectedSymptomIds.clear();
      _unmatchedTokens.clear();
      _currentToken = '';
    });
    _controller.clear();
  }

  void _addSymptom(SymptomEntry symptom) {
    setState(() {
      _selectedSymptomIds.add(symptom.id);
      _currentToken = '';
      _unmatchedTokens.clear();
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrderProvider>();
    final catalogue = context.watch<MedicineProvider>().all();

    // Union of each matched symptom's recommendations, deduplicated by medicine
    // name, narrowed to who the customer is.
    final matches = <MedicineModel>[];
    final seen = <String>{};
    for (final entry in _matchedSymptoms) {
      for (final medicine in entry.recommendationsIn(catalogue)) {
        if (!medicine.isForAge(_targetAgeGroup)) continue;
        if (seen.add(medicine.name.trim().toLowerCase())) {
          matches.add(medicine);
        }
      }
    }

    return Scaffold(
      appBar: const PosAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patient Demographic & Symptoms',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const SafetyBanner(),
            const SizedBox(height: 12),

            SegmentedButton<AgeGroup>(
              segments: const [
                ButtonSegment(
                  value: AgeGroup.both,
                  label: Text('All'),
                  icon: Icon(Icons.people_outline, size: 16),
                ),
                ButtonSegment(
                  value: AgeGroup.child,
                  label: Text('Child'),
                  icon: Icon(Icons.child_care, size: 16),
                ),
                ButtonSegment(
                  value: AgeGroup.adult,
                  label: Text('Adult'),
                  icon: Icon(Icons.person_outline, size: 16),
                ),
              ],
              selected: {_targetAgeGroup},
              onSelectionChanged: (Set<AgeGroup> newSelection) {
                setState(() => _targetAgeGroup = newSelection.first);
              },
            ),
            const SizedBox(height: 12),

            Text(
              'Type Symptoms:',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              onChanged: _handleInput,
              onSubmitted: (_) => _commitCurrent(),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Type symptoms (e.g. fever, headache, cough)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Analyze',
                  icon: const Icon(Icons.analytics_outlined),
                  onPressed: _commitCurrent,
                ),
                helperText: 'Separate multiple symptoms with commas or "and".',
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),

            // Autocomplete suggestions for the token being typed.
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _suggestions
                    .map(
                      (symptom) => ActionChip(
                        avatar: const Icon(Icons.add, size: 14),
                        label: Text(
                          symptom.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _addSymptom(symptom),
                      ),
                    )
                    .toList(),
              ),
            ],

            // Committed symptom chips.
            if (_selectedSymptomIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _matchedSymptoms
                    .map(
                      (symptom) => InputChip(
                        label: Text(
                          symptom.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onDeleted: () => setState(
                          () => _selectedSymptomIds.remove(symptom.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _clearAll,
                  child: const Text(
                    'Clear all',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],

            // Unmatched terms.
            if (_unmatchedTokens.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'No symptom found for: ${_unmatchedTokens.join(', ')}. '
                'Try another word or an alias.',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            ],

            // Clinical notes for the matched symptoms.
            if (_matchedSymptoms.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final symptom in _matchedSymptoms) ...[
                _SymptomNote(symptom: symptom),
                const SizedBox(height: 8),
              ],
            ],

            const SizedBox(height: 10),
            Text(
              'Recommended Medications (${matches.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (_matchedSymptoms.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Based on: ${_matchedSymptoms.map((s) => s.name).join(', ')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (matches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    _selectedSymptomIds.isEmpty
                        ? 'Type a symptom to see suggested medicines.'
                        : 'No matching medication found for selected criteria.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final medicine = matches[index];
                  return _PosProductCard(
                    medicine: medicine,
                    onAdd: () => _addToOrder(context, order, medicine),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SymptomNote extends StatelessWidget {
  const _SymptomNote({required this.symptom});

  final SymptomEntry symptom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            symptom.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(symptom.summary, style: theme.textTheme.bodySmall),
          if (symptom.referralNote case final note?) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// TAB 3: SCAN SKU -- the live text scanner, with its matches below.
///
/// The camera reads printed text (medicine names on a label or prescription),
/// not barcodes: the catalogue is matched on names, and the OCR model is the
/// text recognizer. The preview takes roughly half the screen and the matches
/// scroll underneath it.
class SkuScannerScreen extends StatelessWidget {
  const SkuScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // A bigger preview for the camera, showing more of the prescription.
    final previewHeight = (MediaQuery.sizeOf(context).height * 0.60)
        .clamp(300.0, 600.0)
        .toDouble();

    return Scaffold(
      appBar: const PosAppBar(),
      body: ScanScreen(
        embedded: true,
        previewHeight: previewHeight,
        introMessage: 'Frame the printed medicine name, then scan it',
      ),
    );
  }
}

/// The committed product card: the age badge and the Rx pill, the name, the
/// generic underneath, the dosage line and the price with the Add button.
class _PosProductCard extends StatelessWidget {
  const _PosProductCard({required this.medicine, required this.onAdd});

  final MedicineModel medicine;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 6,
              runSpacing: 4,
              children: _badges(),
            ),
            const SizedBox(height: 8),
            Text(
              medicine.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (medicine.genericKey ?? medicine.packageType case final generic?)
              Text(
                generic,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 6),
            if (medicine.dosageInfo case final dosage?)
              Text(
                'Dosage: $dosage',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    medicine.formattedPrice,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _posPrimary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(72, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: const Text('Add', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The two things worth calling out, per the committed design: a
  /// pediatric-only line, a line children may take only with advice, and
  /// whether a prescription is needed.
  List<Widget> _badges() {
    final badges = <Widget>[];

    if (medicine.ageGroup == AgeGroup.child) {
      badges.add(
        _badge(
          icon: Icons.child_care,
          label: 'PEDIATRIC / CHILD',
          background: const Color(0xFFFEF3C7),
          foreground: const Color(0xFFF59E0B),
        ),
      );
    } else if (medicine.ageGuidance?.kids case AgeSuitability.caution) {
      badges.add(
        _badge(
          icon: Icons.child_care,
          label: 'KIDS: ASK FIRST',
          background: const Color(0xFFFEF3C7),
          foreground: const Color(0xFFF59E0B),
        ),
      );
    } else if (medicine.ageGroup == AgeGroup.adult) {
      badges.add(
        _badge(
          icon: Icons.person_outline,
          label: 'ADULT FORMULA',
          background: const Color(0xFFE0E7FF),
          foreground: const Color(0xFF4338CA),
        ),
      );
    }

    if (medicine.requiresRx) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Rx Required',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return badges;
  }

  static Widget _badge({
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
