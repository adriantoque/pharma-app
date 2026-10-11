import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_mode_controller.dart';

/// Lets the user choose the theme mode, the text size, and reset both.
///
/// The controls read the shared [AppThemeController] rather than holding state
/// of their own, so a change is reflected by the whole app the moment it is
/// made -- including the live preview below the theme selector.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  static const double _minScale = 0.9;
  static const double _maxScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AppThemeController, ThemeMode>(
      (controller) => controller.themeMode,
    );
    final scale = context.select<AppThemeController, double>(
      (controller) => controller.textScale,
    );
    final controller = context.read<AppThemeController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _Section(
                  title: 'Theme',
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('System'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (selection) =>
                            controller.setMode(selection.first),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _ThemePreview(mode: mode),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Text size',
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          const Text('A', style: TextStyle(fontSize: 14)),
                          Expanded(
                            child: Slider(
                              value: scale,
                              min: _minScale,
                              max: _maxScale,
                              divisions: 8,
                              label: '${(scale * 100).round()}%',
                              onChanged: controller.setTextScale,
                            ),
                          ),
                          const Text('A', style: TextStyle(fontSize: 22)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        'The quick brown fox jumps over the lazy dog.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: controller.resetToDefaults,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset to defaults'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small sample surface rendered with the theme the current mode resolves
/// to, so the choice is visible before leaving the screen. [ThemeMode.system]
/// is resolved against the platform brightness here, exactly as the app does.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final brightness = switch (mode) {
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
    };

    return Theme(
      data: buildAppTheme(brightness),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preview', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Text and controls follow the selected theme.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Button'),
                    ),
                    Chip(label: const Text('Chip')),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.surfaceContainerLow,
          child: Column(children: children),
        ),
      ],
    );
  }
}
