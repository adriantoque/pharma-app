import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/audit_repository.dart';
import '../../domain/audit_event.dart';
import '../widgets/activity_row.dart';

/// The full activity log.
///
/// Reached from the Admin home preview's "See all" and from the "Activity log"
/// quick action. Reads the same [AuditRepository] the preview does, so an entry
/// is written once and read in both places.
///
/// Filtering and paging are client-side over one stream, which is why the
/// repository hands the whole log over rather than a query per chip: a
/// pharmacy's log is small, and re-querying on every chip tap would cost more
/// than holding it.
class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key, this.repository});

  /// Injection seam for tests; production reads the provided repository.
  final AuditRepository? repository;

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  AuditCategory _filter = AuditCategory.all;

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository ?? context.read<AuditRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Activity log')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  for (final category in AuditCategory.values)
                    ChoiceChip(
                      label: Text(category.label),
                      selected: _filter == category,
                      onSelected: (_) => setState(() => _filter = category),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AuditEvent>>(
              stream: repository.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _Body(
                    icon: Icons.cloud_off_outlined,
                    title: 'The activity log did not load',
                    detail: snapshot.error.toString(),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final events = (snapshot.data ?? const <AuditEvent>[])
                    .where((event) => _filter.accepts(event.action))
                    .toList(growable: false);

                if (events.isEmpty) {
                  return _Body(
                    icon: Icons.history,
                    title: _filter == AuditCategory.all
                        ? 'No activity yet'
                        : 'Nothing in ${_filter.label}',
                    detail: _filter == AuditCategory.all
                        ? 'Actions taken by admins are recorded here as they '
                              'happen.'
                        : 'No entries in this category so far.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: events.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 60, endIndent: 16),
                  itemBuilder: (context, index) =>
                      ActivityRow(event: events[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
