import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/presentation/providers/medicine_provider.dart';
import 'package:pharmaguide/features/search/presentation/widgets/quantity_sheet.dart';
import 'package:pharmaguide/features/symptom_guide/data/models/medicine_guidance.dart';
import 'package:pharmaguide/features/symptom_guide/data/models/symptom_entry.dart';
import 'package:pharmaguide/features/symptom_guide/presentation/providers/symptom_search_provider.dart';
import 'package:pharmaguide/features/symptom_guide/presentation/widgets/medicine_guidance_card.dart';
import 'package:pharmaguide/features/symptom_guide/presentation/widgets/safety_banner.dart';

/// The detail screen shown after a staff member taps a matched symptom.
///
/// The medicines it shows are resolved live from the counter's own price list
/// through [MedicineProvider], not from a name baked into the guide: the
/// pharmacist's picks lead, and anything the catalogue says is for this symptom
/// follows. Each card carries the real price and shelf count, and its directions
/// come from [MedicineGuidance] -- falling back to a "ask the pharmacist" line
/// rather than the wrong medicine's placeholder text when none is recorded.
class SymptomDetailScreen extends StatelessWidget {
  const SymptomDetailScreen({super.key, required this.symptomId});

  final String symptomId;

  @override
  Widget build(BuildContext context) {
    // Read once: the entry is in-binary and cannot change under the screen.
    final symptom = context.read<SymptomSearchProvider>().byId(symptomId);
    if (symptom == null) {
      return const Scaffold(body: Center(child: Text('Symptom not found')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(symptom.name)),
      body: _SymptomBody(symptom: symptom),
    );
  }
}

class _SymptomBody extends StatelessWidget {
  const _SymptomBody({required this.symptom});

  final SymptomEntry symptom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watched, not read: the catalogue streams in, so a symptom opened before
    // the first snapshot lands fills in as soon as the list arrives.
    final catalogue = context.watch<MedicineProvider>();
    final recommendations = symptom.recommendationsIn(catalogue.all());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Always show the disclaimer so nobody mistakes this for real advice.
          const SafetyBanner(),
          const SizedBox(height: 8),

          Text(symptom.summary, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),

          if (symptom.referralNote case final note?) ...[
            _ReferralNote(note: note),
            const SizedBox(height: 8),
          ],

          ..._recommendations(context, catalogue, recommendations),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _recommendations(
    BuildContext context,
    MedicineProvider catalogue,
    List<MedicineModel> recommendations,
  ) {
    final theme = Theme.of(context);

    if (catalogue.isLoading && catalogue.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (catalogue.error case final error?) {
      return [
        Text(
          'The medicine list could not be read, so no suggestions are shown. '
          'Try again once you are back online.\n$error',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ];
    }

    if (recommendations.isEmpty) {
      return [
        Text(
          'No medicine in the price list is recorded for this symptom. Ask the '
          'pharmacist.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ];
    }

    return [
      for (final medicine in recommendations)
        _card(context, medicine),
    ];
  }

  Widget _card(BuildContext context, MedicineModel medicine) {
    final (howToUse, cautions) = _guidanceFor(medicine);
    final (stockText, stockState) = medicine.stockLine;

    return MedicineGuidanceCard(
      recommendedName: medicine.name,
      howToUse: howToUse,
      cautions: cautions,
      formattedPrice: medicine.formattedPrice,
      stockText: stockText,
      stockState: stockState,
      onAdd: () => _add(context, medicine),
    );
  }

  /// The directions and cautions to show for [medicine].
  ///
  /// Falls back to a "ask the pharmacist" line rather than a generic
  /// placeholder: a medicine with no recorded guidance must not borrow another
  /// medicine's text, or the guide would tell somebody to take paracetamol when
  /// they picked an ointment.
  static (String, String) _guidanceFor(MedicineModel medicine) {
    final guidance = MedicineGuidance.forName(medicine.name);
    if (guidance != null) return (guidance.howToUse, guidance.cautions);
    return (
      'Directions for this medicine are not recorded yet. Ask the pharmacist '
          'how to take it.',
      'Ask the pharmacist about warnings and who should avoid it.',
    );
  }

  /// Adds [medicine] to the order behind the same quantity sheet the search and
  /// scan rows use, so the stock ceiling is enforced in one place.
  Future<void> _add(BuildContext context, MedicineModel medicine) async {
    final order = context.read<OrderProvider>();
    final quantity = await showQuantitySheet(context, medicine: medicine);
    if (quantity == null) return;

    order.add(medicine, quantity);

    // After the await, so the confirmation is not swallowed by the sheet on its
    // way off screen.
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $quantity × ${medicine.name}')),
    );
  }
}

class _ReferralNote extends StatelessWidget {
  const _ReferralNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
    );
  }
}
