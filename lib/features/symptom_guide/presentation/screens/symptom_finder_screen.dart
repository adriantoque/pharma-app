import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../search/data/models/age_guidance.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../../../search/presentation/widgets/product_card.dart';
import '../../../search/presentation/widgets/quantity_sheet.dart';
import '../../data/models/medicine_guidance.dart';
import '../../data/models/symptom_entry.dart';
import '../../data/repositories/symptom_repository.dart';
import '../widgets/safety_banner.dart';

/// The key of the page the finder scrolls in.
///
/// A plain key rather than a global one: the finder can be built twice, and a
/// global key would refuse the second.
const Key recommendationsKey = Key('recommendations');

/// The key of the list the recommendations are drawn in.
const Key recommendationsListKey = Key('recommendationsList');

/// The Symptom Finder tab: what the customer has, and what to hand over.
///
/// The counter picks the symptoms the customer describes, and the guide names
/// the medicines the pharmacist approved for them -- resolved live from the
/// counter's own price list, so a suggestion is always something on the shelf.
///
/// Nothing here is medical advice written by the app. The summaries and the
/// directions are the pharmacist's own words, transcribed into
/// `symptom_catalogue.dart`, and the safety banner says so on every visit.
class SymptomFinderScreen extends StatefulWidget {
  const SymptomFinderScreen({super.key});

  @override
  State<SymptomFinderScreen> createState() => _SymptomFinderScreenState();
}

class _SymptomFinderScreenState extends State<SymptomFinderScreen> {
  /// The guide's content. In-binary, so it is read rather than loaded.
  static const SymptomRepository _repository = StaticSymptomRepository();

  /// The symptoms the counter has picked.
  ///
  /// A set of ids, so the same symptom cannot be counted twice, and so
  /// picking a second symptom does not disturb the first.
  final Set<String> _selected = <String>{};

  /// Who the medicine is for.
  ///
  /// [AgeGroup.both] shows everything, which is the default: most of the
  /// price list says nothing about age, and a guide that hid those lines
  /// behind a question nobody asked would be hiding most of the shelf.
  AgeGroup _ageGroup = AgeGroup.both;

  /// The medicines to offer for the picked symptoms.
  ///
  /// The union of what each picked symptom recommends, one card per medicine:
  /// the same product suggested by two symptoms is one suggestion, not two.
  /// The pharmacist's picks lead, because they are curated in that order.
  static List<MedicineModel> _recommendations(
    List<SymptomEntry> symptoms,
    List<MedicineModel> catalogue,
  ) {
    final result = <MedicineModel>[];
    final seen = <String>{};

    for (final symptom in symptoms) {
      for (final medicine in symptom.recommendationsIn(catalogue)) {
        if (seen.add(medicine.name.trim().toLowerCase())) result.add(medicine);
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watched, not read: the catalogue streams in, so a symptom picked before
    // the first snapshot lands fills in as soon as the list arrives.
    final catalogue = context.watch<MedicineProvider>();
    final order = context.watch<OrderProvider>();

    final symptoms = _repository.all();
    final picked = symptoms.where((s) => _selected.contains(s.id)).toList();
    final medicines = _recommendations(picked, catalogue.all())
        .where((medicine) => medicine.isForAge(_ageGroup))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Symptom Finder')),
      body: Column(
        key: recommendationsKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Always show the disclaimer so nobody mistakes this for real
                // advice.
                const SafetyBanner(),
                const SizedBox(height: 12),

                Text(
                  'Patient Demographic & Symptoms',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),

                // The sample's demographic chips, with an All beside them: the
                // price list mostly records no age, and the guide must still
                // be able to show it when nobody has said who the customer is.
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _ageChip(
                      group: AgeGroup.both,
                      label: 'All',
                      avatar: const Icon(Icons.people_outline, size: 16),
                    ),
                    _ageChip(
                      group: AgeGroup.child,
                      label: 'Pediatric / Child',
                      avatar: const Icon(Icons.child_care, size: 16),
                    ),
                    _ageChip(
                      group: AgeGroup.adult,
                      label: 'Adult',
                      avatar: const Icon(Icons.person_outline, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Text('Select Symptoms:', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final symptom in symptoms) _symptomChip(symptom),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // The rest of the page is the recommendations list the sample gives
          // the remaining height to.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Text(
              'Recommended Medications (${medicines.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: catalogue.isLoading && catalogue.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    key: recommendationsListKey,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    children: [
                      // What the guide says about what was picked, riding with
                      // the list rather than above it: the fixed part of the
                      // page stays the chapter the counter chooses from.
                      for (final symptom in picked) ...[
                        _symptomSummary(symptom),
                        const SizedBox(height: 12),
                      ],

                      if (medicines.isEmpty)
                        _EmptyState(hasSymptoms: picked.isNotEmpty)
                      else
                        for (final medicine in medicines)
                          ProductCard(
                            medicine: medicine,
                            quantity: order.quantityOf(medicine),
                            onTap: () => _add(medicine),
                            onRemove: () => order.remove(medicine),
                            guidance: _guidanceFor(medicine),
                          ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// One choice of who the medicine is for, as the sample draws it: an
  /// avatar-facing chip.
  Widget _ageChip({
    required AgeGroup group,
    required String label,
    required Widget avatar,
  }) {
    final isSelected = _ageGroup == group;

    return ChoiceChip(
      avatar: avatar,
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        // A chip is tapped to choose, never to clear: one of the three is
        // always in force, and clearing would leave the guide with no rule
        // to filter by.
        if (selected) setState(() => _ageGroup = group);
      },
      // Compact chips keep the fixed chapter short enough that the first
      // suggestion is on screen with it -- on a counter's 360dp phone the
      // recommendations would otherwise sit entirely below the fold.
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      selectedColor: AppColors.brandGreenSurface,
      checkmarkColor: AppColors.brandGreen,
      side: const BorderSide(color: AppColors.brandGreenSurfaceBorder),
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected
            ? AppColors.brandGreen
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// One symptom, as a chip the counter can pick.
  Widget _symptomChip(SymptomEntry symptom) {
    final isSelected = _selected.contains(symptom.id);

    return FilterChip(
      label: Text(symptom.name),
      selected: isSelected,
      onSelected: (selected) => setState(() {
        if (selected) {
          _selected.add(symptom.id);
        } else {
          _selected.remove(symptom.id);
        }
      }),
      // Compact for the same reason the demographic chips are: the shorter
      // the fixed chapter, the more of the recommendations the screen shows.
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      selectedColor: AppColors.brandGreenSurface,
      checkmarkColor: AppColors.brandGreen,
      side: const BorderSide(color: AppColors.brandGreenSurfaceBorder),
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected
            ? AppColors.brandGreen
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// What the guide says about a picked symptom.
  ///
  /// The pharmacist's own summary, and the referral note where there is one:
  /// a symptom that should be handed over rather than treated at the counter
  /// has to say so where the counter is reading it.
  Widget _symptomSummary(SymptomEntry symptom) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          symptom.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(symptom.summary, style: theme.textTheme.bodyMedium),
        if (symptom.referralNote case final note?) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
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
    );
  }

  /// The directions and cautions to show on a card.
  ///
  /// Null when nothing is recorded: a medicine with no recorded guidance must
  /// not borrow another medicine's text, or the guide would tell somebody to
  /// take paracetamol when they picked an ointment.
  static ProductGuidance? _guidanceFor(MedicineModel medicine) {
    final guidance = MedicineGuidance.forName(medicine.name);
    if (guidance == null) return null;
    return ProductGuidance(
      howToUse: guidance.howToUse,
      cautions: guidance.cautions,
    );
  }

  /// Adds [medicine] to the order behind the same quantity sheet the scan
  /// rows use, so the stock ceiling is enforced in one place.
  Future<void> _add(MedicineModel medicine) async {
    final order = context.read<OrderProvider>();
    final quantity = await showQuantitySheet(context, medicine: medicine);
    if (quantity == null) return;

    order.add(medicine, quantity);

    // After the await, so the confirmation is not swallowed by the sheet on its
    // way off screen.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $quantity × ${medicine.name}')),
    );
  }
}

/// What the list says when there is nothing to suggest.
///
/// Two cases, and they need different words: nothing picked yet is a step the
/// counter has not taken, while a picked symptom with no match is the end of
/// the guide's advice. Plain sentences rather than a decorated panel, the way
/// the sample speaks.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSymptoms});

  final bool hasSymptoms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Text(
          hasSymptoms
              ? 'No matching medication found for selected criteria.'
              : 'Pick the symptoms the customer has to see suggestions.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
