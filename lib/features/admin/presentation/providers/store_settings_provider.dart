import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../data/models/store_settings_model.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/store_settings_repository.dart';
import '../../domain/audit_event.dart';

/// How far the settings subscription has got.
enum StoreSettingsStatus {
  /// The first snapshot has not arrived yet.
  loading,

  /// A snapshot arrived -- including the "no document yet" one, which still
  /// means the defaults are the truth.
  ready,

  /// The stream failed. The screen offers a retry rather than sitting on a
  /// dead subscription.
  error,
}

/// The store's settings, live, and the writes an admin makes to them.
///
/// Registered above the router, unlike the per-visit [UsersProvider]: staff
/// screens read the expiry window and the low-stock threshold without ever
/// opening the admin workspace, so a subscription that lived only inside the
/// settings screen would leave them guessing.
///
/// One subscription for the whole app, against a singleton document: the
/// stream is cheap, and the alternative -- one per screen -- would put four
/// listeners on one document for no benefit.
///
/// Two side effects of a load are deliberate and documented at their sites:
/// [MedicineModel.lowStockThreshold] is kept in step with the saved
/// threshold, so every stock row re-colours without each reader being wired
/// to this provider.
///
/// Every successful save writes an audit entry. Write and log live in the
/// same method so a future change cannot accidentally skip the log -- the
/// same shape the user-management writes use.
class StoreSettingsProvider extends ChangeNotifier {
  StoreSettingsProvider({
    required StoreSettingsRepository repository,
    required AuditRepository audit,
    required AuthProvider auth,
  }) : // A named parameter cannot be private, so `this._repository` is not
       // available and these are the only shape they can take. The same
       // ignore comments the UsersProvider carries.
       // ignore: prefer_initializing_formals
       _repository = repository,
       // ignore: prefer_initializing_formals
       _audit = audit,
       // ignore: prefer_initializing_formals
       _auth = auth {
    _listen();
  }

  final StoreSettingsRepository _repository;
  final AuditRepository _audit;
  final AuthProvider _auth;

  /// The compiled-in defaults, used when no document exists yet.
  static const StoreSettingsModel _defaults = StoreSettingsModel();

  StreamSubscription<StoreSettingsModel?>? _subscription;

  /// Starts, or restarts, the live subscription to the settings document.
  void _listen() {
    _subscription?.cancel();
    _subscription = _repository.watch().listen(
      (settings) {
        // Either a real document or the "none yet" null, which the screen
        // renders as the model's defaults.
        _snapshot = settings;
        _status = StoreSettingsStatus.ready;
        _saveError = null;

        // The threshold the whole app reads is the one the admin set, not the
        // compiled-in default. Set on every snapshot so a change from another
        // device lands here too.
        MedicineModel.lowStockThreshold =
            (settings ?? _defaults).lowStockThreshold;

        // A save clears the working copy; when the confirming snapshot lands
        // it may still be briefly non-null. Once it matches, drop it, so the
        // Save button does not hang around for a frame after the write.
        if (_working != null && _working == _snapshot) _working = null;
        _safeNotify();
      },
      onError: (Object e) {
        _status = StoreSettingsStatus.error;
        _safeNotify();
      },
    );
  }

  /// Re-subscribes after a stream failure. The screen's Retry button leads
  /// here; a dead subscription is not self-healing.
  void retry() {
    if (_status == StoreSettingsStatus.loading) return;
    _status = StoreSettingsStatus.loading;
    _safeNotify();
    _listen();
  }

  /// What is saved. Null until the first snapshot.
  StoreSettingsModel? _snapshot;

  /// What the admin is editing. Null until something differs from
  /// [_snapshot]; the whole screen reads [settings], which falls back.
  StoreSettingsModel? _working;

  StoreSettingsStatus _status = StoreSettingsStatus.loading;
  String? _saveError;
  bool _isSaving = false;
  bool _disposed = false;

  // ── Reads ────────────────────────────────────────────────────────────────

  StoreSettingsStatus get status => _status;

  bool get isSaving => _isSaving;

  /// Why the last save was refused, for the screen to show.
  String? get saveError => _saveError;

  /// The settings as they should be displayed: the admin's unsaved edits if
  /// there are any, otherwise what is saved, otherwise the defaults.
  ///
  /// Never null -- a fresh install has defaults before it has a document.
  StoreSettingsModel get settings => _working ?? _snapshot ?? _defaults;

  /// What is actually saved, for the "last updated" footer. Null when no
  /// document exists, which the footer renders as "not saved yet".
  StoreSettingsModel? get saved => _snapshot;

  /// True when the admin's edits differ from what is saved. The screen shows
  /// the Save button and guards the back arrow on this.
  bool get isDirty => _working != null;

  // ── Edits ────────────────────────────────────────────────────────────────
  //
  // One method per field rather than a generic `apply(model)`: the screen's
  // editors each change exactly one thing, and a named method for each keeps
  // a call site readable -- `provider.updateName(value)` says what happened
  // where `provider.edit(update)` does not.

  void updateName(String value) => _edit((s) => s.copyWith(name: value));

  /// Empty or whitespace clears the address, rather than storing a field
  /// that holds nothing but spaces.
  void updateAddress(String value) => _applyText(
        value,
        (s) => s.copyWith(address: value),
        clear: (s) => s.withCleared(clearAddress: true),
      );

  void updatePhone(String value) => _applyText(
        value,
        (s) => s.copyWith(phone: value),
        clear: (s) => s.withCleared(clearPhone: true),
      );

  void updateOpen(int minutes) =>
      _edit((s) => s.copyWith(openMinutes: minutes));

  void updateClose(int minutes) =>
      _edit((s) => s.copyWith(closeMinutes: minutes));

  void updateLowStockThreshold(int value) =>
      _edit((s) => s.copyWith(lowStockThreshold: value));

  void updateExpiryWarningDays(int days) =>
      _edit((s) => s.copyWith(expiryWarningDays: days));

  void updateReorderCoverageDays(int days) =>
      _edit((s) => s.copyWith(reorderCoverageDays: days));

  /// Routes a one-field edit through the working copy, creating it from
  /// [settings] on the first edit of a session.
  void _edit(StoreSettingsModel Function(StoreSettingsModel) change) {
    _working = change(settings);
    _safeNotify();
  }

  /// The text fields distinguish "cleared" from "unchanged": an empty edit
  /// clears the field, a whitespace-only edit is treated the same way, and
  /// anything else replaces it.
  void _applyText(
    String value,
    StoreSettingsModel Function(StoreSettingsModel) set, {
    required StoreSettingsModel Function(StoreSettingsModel) clear,
  }) {
    final trimmed = value.trim();
    _edit(trimmed.isEmpty ? clear : set);
  }

  // ── Saving ───────────────────────────────────────────────────────────────

  /// Writes the working copy, and logs what changed.
  ///
  /// Returns true on success. False comes with [saveError] filled -- a
  /// validation problem first ("closing time must be after opening time"),
  /// then a Firestore failure.
  ///
  /// On success the working copy becomes the snapshot immediately, so the
  /// Save button and the dirty guard go away at once rather than waiting for
  /// the confirming snapshot to arrive.
  Future<bool> save() async {
    final working = _working;
    if (working == null || _isSaving) return true;

    final problems = working.validationProblems();
    if (problems.isNotEmpty) {
      _saveError = problems.first;
      _safeNotify();
      return false;
    }

    _isSaving = true;
    _saveError = null;
    _safeNotify();

    try {
      final actor = _auth.user;

      // The before-state is read before the write, not after: the write
      // itself may confirm through the stream before the audit entry is
      // recorded, and a diff taken then would compare the new against the
      // new and log nothing.
      final previous = _snapshot;
      final summary = _summary(previous, working);
      final before = _changedFields(previous, working);

      final saved = working.copyWith(updatedBy: actor?.name ?? 'Unknown');
      await _repository.save(saved);

      await _audit.record(
        action: AuditAction.settingsUpdated,
        actorUid: actor?.id ?? '',
        actorName: actor?.name ?? 'Unknown',
        summary: summary,
        // No targetId: a change to a singleton like store settings acts on
        // nothing in particular, and the audit screen's Settings chip is the
        // way to find these entries.
        before: before,
        after: _allFields(working),
      );

      _snapshot = saved;
      _working = null;
      return true;
    } catch (e) {
      _saveError = 'Could not save the settings. $e';
      return false;
    } finally {
      _isSaving = false;
      _safeNotify();
    }
  }

  /// Discards every unsaved edit, back to what is saved. The back-arrow
  /// dialog's "Discard" leads here.
  void discard() {
    if (_working == null) return;
    _working = null;
    _safeNotify();
  }

  /// One line for the log: what changed, by the names an admin would use.
  /// A save that somehow changed nothing writes "Updated store settings"
  /// and nothing more.
  String _summary(StoreSettingsModel? before, StoreSettingsModel after) {
    final labels = _changedLabels(before, after);
    if (labels.isEmpty) return 'Updated store settings';
    return 'Updated store settings: ${labels.join(', ')}';
  }

  /// Only the fields that differ, as a map the audit entry can store -- the
  /// same shape the user-management entries carry.
  Map<String, dynamic> _changedFields(
    StoreSettingsModel? before,
    StoreSettingsModel after,
  ) {
    final fields = <String, dynamic>{};
    final old = before;
    if (old == null || old.name != after.name) {
      fields['name'] = after.name.trim();
    }
    if (old == null || old.address != after.address) {
      fields['address'] = after.address ?? '(cleared)';
    }
    if (old == null || old.phone != after.phone) {
      fields['phone'] = after.phone ?? '(cleared)';
    }
    if (old == null || old.openMinutes != after.openMinutes) {
      fields['opensAt'] = StoreSettingsModel.formatMinutes(after.openMinutes);
    }
    if (old == null || old.closeMinutes != after.closeMinutes) {
      fields['closesAt'] = StoreSettingsModel.formatMinutes(after.closeMinutes);
    }
    if (old == null || old.lowStockThreshold != after.lowStockThreshold) {
      fields['lowStockThreshold'] = after.lowStockThreshold;
    }
    if (old == null || old.expiryWarningDays != after.expiryWarningDays) {
      fields['expiryWarningDays'] = after.expiryWarningDays;
    }
    if (old == null || old.reorderCoverageDays != after.reorderCoverageDays) {
      fields['reorderCoverageDays'] = after.reorderCoverageDays;
    }
    return fields;
  }

  /// Every editable field, as the audit entry's `after`. The user-management
  /// entries store the whole resulting object the same way, so a reader of
  /// one entry can see the state without the other.
  Map<String, dynamic> _allFields(StoreSettingsModel model) {
    return {
      'name': model.name.trim(),
      'address': model.address ?? '(cleared)',
      'phone': model.phone ?? '(cleared)',
      'opensAt': StoreSettingsModel.formatMinutes(model.openMinutes),
      'closesAt': StoreSettingsModel.formatMinutes(model.closeMinutes),
      'lowStockThreshold': model.lowStockThreshold,
      'expiryWarningDays': model.expiryWarningDays,
      'reorderCoverageDays': model.reorderCoverageDays,
    };
  }

  /// The human names for what changed, in a stable order.
  List<String> _changedLabels(
    StoreSettingsModel? before,
    StoreSettingsModel after,
  ) {
    final labels = <String>[];
    final old = before;
    if (old == null || old.name != after.name) labels.add('name');
    if (old == null || old.address != after.address) labels.add('address');
    if (old == null || old.phone != after.phone) labels.add('phone');
    if (old == null || old.openMinutes != after.openMinutes) {
      labels.add('opening hours');
    }
    if (old == null || old.closeMinutes != after.closeMinutes) {
      labels.add('opening hours');
    }
    if (old == null || old.lowStockThreshold != after.lowStockThreshold) {
      labels.add('low-stock threshold');
    }
    if (old == null || old.expiryWarningDays != after.expiryWarningDays) {
      labels.add('expiry warning');
    }
    if (old == null || old.reorderCoverageDays != after.reorderCoverageDays) {
      labels.add('reorder coverage');
    }
    return labels;
  }

  /// Clears a save error once the screen has shown it.
  void clearSaveError() {
    if (_saveError == null) return;
    _saveError = null;
    _safeNotify();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
