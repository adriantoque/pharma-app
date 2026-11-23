import 'package:flutter/material.dart';

/// Opens a one-choice picker and hands back the chosen value.
///
/// Tapping a choice closes the sheet immediately -- there is no Save step,
/// because a choice sheet with a Save button makes the admin confirm a
/// decision they made the moment they read the labels. Cancelling is the
/// back gesture or the scrim, which return null.
///
/// Used for settings whose value comes from a short fixed list, such as the
/// expiry warning window.
Future<T?> showSettingsChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<SettingsChoice<T>> choices,
  required T selected,
  String? helper,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (_) => _SettingsChoiceSheet(
      title: title,
      choices: choices,
      selected: selected,
      helper: helper,
    ),
  );
}

/// One option on a choice sheet: the value it selects and how it reads.
class SettingsChoice<T> {
  const SettingsChoice(this.value, this.label);

  final T value;
  final String label;
}

class _SettingsChoiceSheet<T> extends StatelessWidget {
  const _SettingsChoiceSheet({
    required this.title,
    required this.choices,
    required this.selected,
    required this.helper,
  });

  final String title;
  final List<SettingsChoice<T>> choices;
  final T selected;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 8),
            Text(
              helper!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in choices)
                ChoiceChip(
                  label: Text(choice.label),
                  selected: choice.value == selected,
                  onSelected: (_) => Navigator.of(context).pop(choice.value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
