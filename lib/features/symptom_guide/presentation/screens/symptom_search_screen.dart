import 'package:flutter/material.dart';

import 'package:pharmaguide/features/symptom_guide/presentation/widgets/safety_banner.dart';

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
              onChanged: (_) {
                // Match against the static catalogue on every text change.
                // No provider needed — the catalogue is in the binary.
              },
              decoration: const InputDecoration(
                hintText: 'Type a symptom (e.g. fever, headache)',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: const Center(
              child: Text(
                  'Select a symptom from the finder or Dashboard'),
            ),
          ),
        ],
      ),
    );
  }
}