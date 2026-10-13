import 'package:flutter/material.dart';
import '../../data/models/symptom_entry.dart';

/// One row in the symptom-search result list.
class SymptomResultRow extends StatelessWidget {
  const SymptomResultRow({
    super.key,
    required this.symptom,
    required this.onTap,
  });

  final SymptomEntry symptom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.healing_outlined,
            size: 21,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(symptom.name),
        subtitle: Text(
          symptom.summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}