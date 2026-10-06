import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/feature_entry.dart';
import '../providers/feature_search_provider.dart';
import '../widgets/feature_row.dart';
import '../widgets/finder_search_field.dart';

/// The feature finder: type part of a screen's name, tap the row, go there.
///
/// Navigation is injected rather than called directly. [onNavigate] defaults to
/// doing nothing, so this screen can be built and driven in a widget test with
/// no router in sight, and the wiring step is one closure at the call site
/// instead of a change in here.
class FinderScreen extends StatefulWidget {
  const FinderScreen({super.key, this.onNavigate});

  /// Called with the tapped entry. The caller decides what "going there" means.
  final void Function(FeatureEntry entry)? onNavigate;

  @override
  State<FinderScreen> createState() => _FinderScreenState();
}

class _FinderScreenState extends State<FinderScreen> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeatureSearchProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Find a feature')),
      body: Column(
        children: [
          FinderSearchField(
            controller: _controller,
            onChanged: provider.updateQuery,
            onClear: () {
              _controller.clear();
              provider.clear();
            },
          ),
          _ResultCount(
            count: provider.resultCount,
            filtered: !provider.isUnfiltered,
          ),
          Expanded(
            child: provider.hasNoMatches
                ? _NoMatches(query: provider.query)
                : ListView.builder(
                    // Keyed on the query so the list rebuilds from scratch when
                    // the filter changes. Without it, ListView reuses rows by
                    // index and a narrowed list animates entries into the wrong
                    // positions, which reads as the results having shuffled.
                    key: ValueKey(provider.query),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: provider.resultCount,
                    itemBuilder: (context, index) {
                      final entry = provider.results[index];
                      return FeatureRow(
                        entry: entry,
                        onTap: () => widget.onNavigate?.call(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// "12 features" or "3 matching".
class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count, required this.filtered});

  final int count;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          filtered ? '$count matching' : '$count features',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Shown when a query matched nothing.
///
/// A local widget rather than the price list's `NoResults`, which says "No
/// medicines found matching X" and is otherwise identical. The wording here
/// adds the one thing that helps on this screen -- that the answer might be a
/// different word -- because unlike a medicine name, a feature can be found by
/// several.
class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No feature matches "$query"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a shorter word, or the name of the screen.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
