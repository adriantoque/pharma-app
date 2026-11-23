import 'package:flutter/foundation.dart';

/// The kind of thing that gets written to the audit log.
///
/// An enum rather than a free-form string so the Audit screen can filter by
/// category without a schema, and so a typo cannot invent a category that
/// nothing else knows about. The wire format is the enum's `name`, which is
/// stable.
///
/// Phase A covers admin actions only. The staff actions -- approving an
/// order, counting stock -- will be added here when the providers that
/// perform them are retrofitted.
enum AuditAction {
  // User management
  userCreated,
  userUpdated,
  userDeactivated,
  userReactivated,
  userPasswordReset,

  // Store settings
  settingsUpdated;

  String get label => switch (this) {
        AuditAction.userCreated => 'User created',
        AuditAction.userUpdated => 'User updated',
        AuditAction.userDeactivated => 'User deactivated',
        AuditAction.userReactivated => 'User reactivated',
        AuditAction.userPasswordReset => 'Password reset sent',
        AuditAction.settingsUpdated => 'Settings updated',
      };

  /// Which chip on the Audit screen this belongs to.
  AuditCategory get category => switch (this) {
        AuditAction.userCreated ||
        AuditAction.userUpdated ||
        AuditAction.userDeactivated ||
        AuditAction.userReactivated ||
        AuditAction.userPasswordReset =>
          AuditCategory.users,
        AuditAction.settingsUpdated => AuditCategory.settings,
      };

  static AuditAction? fromStorage(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final action in AuditAction.values) {
      if (action.name == value) return action;
    }
    return null;
  }
}

/// Groupings shown as filter chips on the Audit screen.
enum AuditCategory {
  all('All'),
  users('Users'),
  settings('Settings');

  const AuditCategory(this.label);

  final String label;

  bool accepts(AuditAction action) => switch (this) {
        AuditCategory.all => true,
        AuditCategory.users => action.category == AuditCategory.users,
        AuditCategory.settings => action.category == AuditCategory.settings,
      };
}

/// One entry in the append-only log.
///
/// Immutable, and never edited. The only field that can change is nothing:
/// an entry written wrong is a wrong entry. If the app needs to correct an
/// event, it writes another one.
@immutable
class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.action,
    required this.actorUid,
    required this.actorName,
    required this.summary,
    required this.at,
    this.targetId,
    this.before,
    this.after,
  });

  final String id;
  final AuditAction action;

  /// The account that performed the action. Kept even if the account is
  /// later deactivated, because "Juan did this" is the entire point of the
  /// log and a deactivated account still did what it did.
  final String actorUid;
  final String actorName;

  /// One line a person can read: "Created user Juan Dela Cruz (staff)".
  ///
  /// Stored rather than rendered from the structured fields, so the log
  /// reads the same in a year even if the labels change.
  final String summary;

  /// The id of the thing acted on, when there is one. Null for changes to
  /// singletons like store settings.
  final String? targetId;

  /// The relevant state before and after, when it fits in a document.
  ///
  /// Null for actions with no meaningful before (creating a user) or too
  /// much state to store (the whole settings object is stored, but nothing
  /// larger).
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  final DateTime at;

  factory AuditEvent.fromFirestore(String id, Map<String, dynamic> data) {
    return AuditEvent(
      id: id,
      action: AuditAction.fromStorage(data['action'] as String?) ??
          AuditAction.userUpdated,
      actorUid: data['actorUid'] as String? ?? '',
      actorName: data['actorName'] as String? ?? 'Unknown',
      summary: data['summary'] as String? ?? '',
      targetId: data['targetId'] as String?,
      before: (data['before'] as Map?)?.cast<String, dynamic>(),
      after: (data['after'] as Map?)?.cast<String, dynamic>(),
      at: (data['at'] as dynamic)?.toDate() as DateTime? ?? DateTime.now(),
    );
  }
}