import 'package:flutter/material.dart';

/// The disclaimer shown wherever the symptom guide offers advice.
///
/// Deliberately loud and always present, not a dismissible hint. A tool that
/// suggests a medicine is one a busy staff member can start trusting as a
/// diagnosis, and this is the sentence that says it is not one.
class SafetyBanner extends StatelessWidget {
  const SafetyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: scheme.onErrorContainer, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Decision support for counter staff — not a diagnosis. Confirm '
                'suitability and dosing with the pharmacist, and check allergies '
                'and existing prescriptions before suggesting anything.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
