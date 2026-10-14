import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:pharmaguide/features/symptom_guide/presentation/providers/symptom_search_provider.dart';
import 'package:pharmaguide/features/symptom_guide/presentation/widgets/safety_banner.dart';
import 'package:pharmaguide/features/symptom_guide/presentation/widgets/symptom_result_row.dart';

/// The search screen for the Symptom Guide.
///
/// Staff type a symptom and see matching entries from the guide's catalogue.
/// The content is supplied and reviewed by the pharmacist.
///
/// The filtering itself lives in [SymptomSearchProvider], which watches the
/// query and guards against notifying on an unchanged one, so typing only
/// rebuilds this list when the result set can actually have moved.
class SymptomSearchScreen extends StatelessWidget {
  const SymptomSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SymptomSearchProvider>();
    final results = provider.results;

    return Scaffold(
      appBar: AppBar(title: const Text('Symptom Guide')),
      body: Column(
        children: [
          // Always show the disclaimer so nobody mistakes this for real advice.
          const SafetyBanner(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: provider.updateQuery,
              decoration: const InputDecoration(
                hintText: 'Type a symptom (e.g. fever, headache)',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? _Empty(
                    message: provider.hasNoMatches
                        ? 'No symptom matches "${provider.query.trim()}". '
                              'Try another word, or search a medicine by name.'
                        : 'No symptoms are in the guide yet.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: results.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = results[index];
                      return SymptomResultRow(
                        symptom: entry,
                        onTap: () => context.pushNamed(
                          'home-symptom-detail',
                          pathParameters: {'symptomId': entry.id},
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
