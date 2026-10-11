import 'package:flutter/material.dart';

/// Search input styled by the shared application input theme.
class FinderSearchField extends StatelessWidget {
  const FinderSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  /// This screen exists only to be searched, so it is focused on arrival.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        autofocus: autofocus,
        decoration: InputDecoration(
          hintText: 'Search features',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear',
                  onPressed: onClear,
                ),
        ),
      ),
    );
  }
}
