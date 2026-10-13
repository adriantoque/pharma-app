import 'package:flutter/material.dart';

import 'package:pharmaguide/features/symptom_guide/data/repositories/symptom_catalogue.dart';
import 'package:pharmaguide/features/symptom_guide/presentation/widgets/safety_banner.dart';
import 'package:pharmaguide/features/symptom_guide/presentation/widgets/medicine_guidance_card.dart';

/// The detail screen shown after a staff member taps a matched symptom.
class SymptomDetailScreen extends StatelessWidget {
  const SymptomDetailScreen({
    super.key,
    required this.symptomId,
  });

  final String symptomId;

  @override
  Widget build(BuildContext context) {
    // Read the static catalogue directly; no provider needed.
    final catalogue = symptomCatalogue;
    // Simple lookup since List doesn't have byId.
    // Simple lookup since List doesn't have byId.
    // Simple lookup since List doesn't have byId.
    dynamic symptomEntry;
    for (final entry in catalogue) {
      if (entry.id == symptomId) {
        symptomEntry = entry;
        break;
      }
    }
    if (symptomEntry == null) {
      return const Scaffold(
        body: Center(child: Text('Symptom not found')),
      );
    }

    /// The medicine name we will show in the guidance card.
    final firstMedicineName = symptomEntry.medicineNames.isNotEmpty
        ? symptomEntry.medicineNames.first
        : '';

    /// Placeholder directions/cautions — the real text will be supplied by the
    /// pharmacist and replace these [isDraft] marked entries.
    final howToUse = '[Placeholder] Swallow with water. Can be taken with or without food. Replace with the pharmacist\'s wording.';
    final cautions = '[Placeholder] Do not take with other paracetamol products. Ask the pharmacist if pregnant. Replace with the pharmacist\'s wording.';

    /// Dummy price/stock for the "Add to order" card.
    final dummyPrice = '₱180.00';
    final dummyStock = '5 in stock';

    return Scaffold(
      appBar: AppBar(title: Text(symptomEntry.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Safety banner always present
            const SafetyBanner(),
            const SizedBox(height: 8),

            // Summary
            Text(
              symptomEntry.summary,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),

            // Referral note (if any)
            if (symptomEntry.referralNote != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  symptomEntry.referralNote!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Guidance / medicine card
            if (symptomEntry.medicineNames.isNotEmpty) ...[
              MedicineGuidanceCard(
                recommendedName: firstMedicineName,
                howToUse: howToUse,
                cautions: cautions,
                formattedPrice: dummyPrice,
                stockText: dummyStock,
                onAdd: () {
                  // In a full implementation this would add the medicine to the
                  // current order. For now we just show a snackbar.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to order')),
                  );
                },
              ),
            ],

            if (symptomEntry.medicineNames.isEmpty && symptomEntry.referralNote == null) ...[
              const Text(
                'No medicines are recommended for this symptom.',
                style: TextStyle(color: Colors.red),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}