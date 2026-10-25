import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../orders/presentation/providers/order_provider.dart';
import '../../../search/data/models/age_guidance.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../scan/presentation/screens/scan_screen.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../../../symptom_guide/data/repositories/symptom_repository.dart';
import '../../../symptom_guide/presentation/widgets/safety_banner.dart';

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
const Color _posPrimary = Color(0xFF0284C7);

/// The app bar shared by all three tabs: the pharmacy word-mark, the routes
/// out of the POS (history, profile, the management screens). The cart has
/// its own destination in the staff bar now.
///
/// The committed design keeps its word-mark row leading-aligned, so the
/// theme's centerTitle is deliberately off here.
AppBar _posAppBar(BuildContext context) {
  return AppBar(
    backgroundColor: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    // The word-mark scales down rather than overflowing on narrow phones:
    // with three actions the title row has little room on a 360dp screen,
    // and a hard overflow there would be worse than a slightly smaller mark.
    title: const FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(Icons.local_pharmacy, color: _posPrimary),
          SizedBox(width: 8),
          Text(
            'PharmaStaff POS',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    ),
    actions: [
      IconButton(
        tooltip: 'Profile',
        icon: const Icon(Icons.account_circle_outlined),
        onPressed: () => context.pushNamed('home-profile'),
      ),
      // The management screens live behind a menu rather than their own tabs:
      // the committed bar is exactly three destinations wide. They are still
      // routed underneath, so the menu only has to name them.
      PopupMenuButton<String>(
        tooltip: 'More',
        icon: const Icon(Icons.more_vert),
        onSelected: (route) => context.pushNamed(route),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'home-expiring', child: Text('Expiring Meds')),
          PopupMenuItem(
            value: 'home-notifications',
            child: Text('Notifications'),
          ),
          PopupMenuItem(value: 'medicines', child: Text('Medicine list')),
          PopupMenuItem(value: 'orders-history', child: Text('Order history')),


        ],
      ),
      const SizedBox(width: 4),
    ],
  );
}

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

  _showQuantityDialog(context, order, medicine);  }

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
        content:
            Text('${widget.medicine.name} added to cart ($_selectedQuantity)'),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _posAppBar(context),
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
    final names = widget.medicines
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
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search medicine, generic name...',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
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
                        selectedColor: const Color(0xFFE0F2FE),
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

/// TAB 2: SYMPTOM FINDER -- what the customer has, what to hand over.
class PosSymptomFinderScreen extends StatefulWidget {
  const PosSymptomFinderScreen({super.key});

  @override
  State<PosSymptomFinderScreen> createState() => _PosSymptomFinderScreenState();
}

class _PosSymptomFinderScreenState extends State<PosSymptomFinderScreen> {
  static const SymptomRepository _repository = StaticSymptomRepository();

  AgeGroup _targetAgeGroup = AgeGroup.child;
  final Set<String> _selectedSymptoms = {};

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrderProvider>();
    final catalogue = context.read<MedicineProvider>().all();

    final symptoms = _repository.all();
    final picked = symptoms
        .where((entry) => _selectedSymptoms.contains(entry.name))
        .toList();

    // The union of what each picked symptom recommends -- deduplicated by
    // [SymptomEntry.recommendationsIn] -- narrowed to who the customer is.
    final matches = <MedicineModel>[];
    final seen = <String>{};
    for (final entry in picked) {
      for (final medicine in entry.recommendationsIn(catalogue)) {
        if (!medicine.isForAge(_targetAgeGroup)) continue;
        if (seen.add(medicine.name.trim().toLowerCase())) {
          matches.add(medicine);
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _posAppBar(context),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The committed heading, with the app's standing disclaimer right
            // under it: the finder may suggest, it must not diagnose.
            const Text(
              'Patient Demographic & Symptoms',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const SafetyBanner(),
            const SizedBox(height: 12),
            Row(
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.child_care, size: 16),
                  label: const Text('Pediatric / Child'),
                  selected: _targetAgeGroup == AgeGroup.child,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _targetAgeGroup = AgeGroup.child);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.person, size: 16),
                  label: const Text('Adult'),
                  selected: _targetAgeGroup == AgeGroup.adult,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _targetAgeGroup = AgeGroup.adult);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Select Symptoms:',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: symptoms
                  .map(
                    (symptom) => FilterChip(
                      label: Text(
                        symptom.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _selectedSymptoms.contains(symptom.name),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSymptoms.add(symptom.name);
                          } else {
                            _selectedSymptoms.remove(symptom.name);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Recommended Medications (${matches.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching medication found for selected criteria.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final medicine = matches[index];
                        return _PosProductCard(
                          medicine: medicine,
                          onAdd: () => _addToOrder(context, order, medicine),
                        );
                      },
                    ),
            ),
          ],
        ),
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
    // Roughly half the screen, clamped so it stays useful on a short phone and
    // does not swallow a tablet.
    final previewHeight =
        (MediaQuery.sizeOf(context).height * 0.45).clamp(240.0, 420.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _posAppBar(context),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            const SizedBox(height: 6),
            if (medicine.dosageInfo case final dosage?)
              Text(
                'Dosage: $dosage',
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  medicine.formattedPrice,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _posPrimary,
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _posPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Add'),
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
      badges.add(_badge(
        icon: Icons.child_care,
        label: 'PEDIATRIC / CHILD',
        background: const Color(0xFFFEF3C7),
        foreground: const Color(0xFFD97706),
      ));
    } else if (medicine.ageGuidance?.kids case AgeSuitability.caution) {
      badges.add(_badge(
        icon: Icons.child_care,
        label: 'KIDS: ASK FIRST',
        background: const Color(0xFFFEF3C7),
        foreground: const Color(0xFFD97706),
      ));
    } else if (medicine.ageGroup == AgeGroup.adult) {
      badges.add(_badge(
        icon: Icons.person_outline,
        label: 'ADULT FORMULA',
        background: const Color(0xFFE0E7FF),
        foreground: const Color(0xFF4338CA),
      ));
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

