import 'dart:async';

import 'package:pharmaguide/features/admin/data/repositories/audit_repository.dart';
import 'package:pharmaguide/features/admin/domain/audit_event.dart';

/// An in-memory [AuditRepository] for the admin screen tests.
///
/// [watchAll] hands over a broadcast stream the test drives with [emit], and
/// [record] appends to a list the test can assert on. Both sides exist because
/// the home preview and the full log read and write the same repository.
class FakeAuditRepository implements AuditRepository {
  final StreamController<List<AuditEvent>> _controller =
      StreamController<List<AuditEvent>>.broadcast();

  /// Every entry passed to [record], in order.
  final List<AuditEvent> recorded = [];

  @override
  Stream<List<AuditEvent>> watchAll() => _controller.stream;

  @override
  Future<void> record({
    required AuditAction action,
    required String actorUid,
    required String actorName,
    required String summary,
    String? targetId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    recorded.add(
      AuditEvent(
        id: '${recorded.length}',
        action: action,
        actorUid: actorUid,
        actorName: actorName,
        summary: summary,
        targetId: targetId,
        before: before,
        after: after,
        at: DateTime.now(),
      ),
    );
  }

  /// Sends a fresh snapshot, as a Firestore listener would.
  void emit(List<AuditEvent> events) {
    if (!_controller.isClosed) _controller.add(events);
  }

  void dispose() {
    if (!_controller.isClosed) unawaited(_controller.close());
  }
}
