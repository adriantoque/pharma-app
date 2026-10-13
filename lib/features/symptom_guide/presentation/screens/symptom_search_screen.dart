import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pharmaguide/core/utils/search_text.dart';
import 'package:pharmaguide/features/symptom_guide/data/repositories/symptom_catalogue.dart';
import 'package:pharmaguide/features/symptom_guide/presentation/widgets/safety_banner.dart';
import 'package:pharmaguide/features/symptom_guide/presentation/widgets/symptom_result_row.dart';

/// The search screen for the Symptom Guide.
///
/// Staff type a symptom and see matching medicine suggestions from the static
/// catalogue. The catalogue content is supplied and reviewed by the pharmacist;
/// the scaffold ships with placeholders ([isDraft]) so the screens work end to
/// end before the real text lands.
class SymptomSearchScreen extends StatelessWidget {
  const SymptomSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Symptom Guide')),
      body: Column(
        children: [
          // Always show the disclaimer so nobody mistakes this for real advice
          const SafetyBanner(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (String value) {
                // No provider — we match against the static catalogue below.
              },
              decoration: const InputDecoration(
                hintText: 'Type a symptom (e.g. fever, headache)',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: builder,
          ),
        ],
      ),
    );
  }

  /// The filtered list of symptoms, built once per [context] change.
  List<SymptomEntry> get _matchedSymptoms {
    final query = symptomSearchController.text.trim();
    if (query.isEmpty) return const [];
    final needle = normaliseForSearch(query);
    if (needle.isEmpty) return const [];
    return symptomCatalogue.where((entry) => entry.matches(query)).toList()
      ..sort(SymptomEntry.compareByName);
  }

  // A controller for the text field, used to read the query in _matchedSymptoms.
  final TextEditingController symptomSearchController = TextEditingController();

  Widget get builder {
    final List<SymptomEntry> symptoms = _matchedSymptoms;
    if (symptomSearchController.text.isEmpty) {
      return const Center(child: Text('Type a symptom to see suggestions'));
    }
    if (symptoms.isEmpty) {
      return const Center(child: Text('No matches found'));
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: symptoms.map((symptom) => SymptomResultRow(
        symptom: symptom,
        onTap: () {
          // Push the detail screen with the symptom id.
          context.pushNamed(
            'home-symptom-detail',
            pathParameters: {'symptomId': symptom.id},
          );
        },
      )).toList(),
    );
  }
}