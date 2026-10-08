import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/audit_event.dart';

/// The append-only activity log.
///
/// Two jobs, kept in one class because they are two halves of one thing: a
/// caller that writes an entry and a caller that reads the log are both
/// talking about the same collection. Split them and a future schema change
/// touches both files anyway.
///
/// Writing never fails the action it describes. A user created successfully
/// in Firebase but not logged is a smaller problem than a user who cannot be
/// created because the log write timed out, so [record] swallows its own
/// errors. The consequence is a log that can be slightly incomplete; the
/// alternative is a log that can block the app.
class AuditRepository {
  AuditRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('audit');

  /// Writes one entry.
  ///
  /// Returns immediately when `actorUid` is empty -- a caller that does not
  /// know who is acting should not be writing entries on their behalf.
  Future<void> record({
    required AuditAction action,
    required String actorUid,
    required String actorName,
    required String summary,
    String? targetId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    if (actorUid.isEmpty) return;
    try {
      await _collection.add({
        'action': action.name,
        'actorUid': actorUid,
        'actorName': actorName,
        'summary': summary,
        'targetId': targetId,
        'before': before,
        'after': after,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Swallowed on purpose. See the class doc.
    }
  }

  /// Every entry, newest first.
  ///
  /// The Audit screen filters and pages client-side, so this is one stream
  /// rather than a query per filter. A pharmacy's log is small enough --
  /// hundreds of entries a month -- that the network cost of loading it
  /// whole is less than the round trip of a filtered query each time a chip
  /// is tapped.
  Stream<List<AuditEvent>> watchAll() {
    return _collection
        .orderBy('at', descending: true)
        .limit(500)
        .snapshots()
        .map((snapshot) => [
              for (final doc in snapshot.docs)
                AuditEvent.fromFirestore(doc.id, doc.data()),
            ]);
  }
}