import 'package:flutter/material.dart';

/// The finder's search box.
///
/// A near-copy of `DashboardScreen`'s own `SearchField` rather than an import
/// of it. That one is declared privately inside `dashboard_screen.dart`, and
/// promoting it to a shared widget to serve two callers would be a refactor of
/// a screen this feature is not otherwise touching.
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

  /// Defaults to true, unlike the dashboard's field. This screen exists only to
  /// be searched, so requiring a tap before typing is a step with nothing
  /// behind it.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
