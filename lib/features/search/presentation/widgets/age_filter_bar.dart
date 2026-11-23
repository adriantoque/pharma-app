import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/age_guidance.dart';

/// Who the medicine on show is for: All, Child, or Adult.
///
/// A segmented control rather than chips, because the three choices are one
/// decision about the customer in front of the counter, and a switch that can
/// only be in one position says so at a glance.
///
/// Shared by the sale shelf and the symptom guide, so the two cannot drift
/// apart: a staff member who learns the control on one screen finds the same
/// control on the other.
class AgeFilterBar extends StatelessWidget {
  const AgeFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.label,
  });

  /// The group currently in force.
  final AgeGroup selected;

  /// Called with the group the user picked.
  final ValueChanged<AgeGroup> onChanged;

  /// The word in front of the control, when the screen has room for one.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final control = SegmentedButton<AgeGroup>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: AgeGroup.both,
          icon: Icon(Icons.people_outline, size: 16),
          label: Text('All'),
        ),
        ButtonSegment(
          value: AgeGroup.child,
          icon: Icon(Icons.child_care, size: 16),
          label: Text('Child'),
        ),
        ButtonSegment(
          value: AgeGroup.adult,
          icon: Icon(Icons.person_outline, size: 16),
          label: Text('Adult'),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.brandGreenSurface
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.brandGreen
              : theme.colorScheme.onSurfaceVariant,
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.brandGreenSurfaceBorder),
        ),
        textStyle: WidgetStatePropertyAll(theme.textTheme.labelMedium),
      ),
    );

    final word = switch (label) {
      final label? => Text(label, style: theme.textTheme.labelLarge),
      null => null,
    };

    if (word == null) {
      return SizedBox(width: double.infinity, child: control);
    }

    return Row(
      children: [
        word,
        const SizedBox(width: 8),
        Expanded(child: control),
      ],
    );
  }
}
