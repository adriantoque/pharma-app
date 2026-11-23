/// The price list for a signed-in account: Firestore's catalogue, mirrored into
/// the local database.
///
/// Firestore is the source of truth for the *catalogue* -- names, prices,
/// aliases, the descriptive fields -- and the SQLite cache is what makes it
/// durable and what survives the cases the Firestore disk cache does not: an
/// app killed mid-queue, and the native cache being evicted under its LRU
/// budget. The bundle seeds the database once, and from then on the database
/// is the fallback.
///
/// Reading: every emission is the merged view -- local rows with the server's
/// answer laid over them (see `mergeMedicines`). Each server snapshot is
/// mirrored into the database, so the cache converges on the server's
/// catalogue without any further wiring.
///
/// Writing: local only. Medicine edits -- a stock count, an expiry, an upsert,
/// an import -- are written to the database and nowhere else. They used to go
/// on to Firestore after the local write, and the server kept refusing them
/// (`PERMISSION_DENIED` on `pharmacy/medicines/items`), which rolled the edit
/// back out of the cache it had just been painted into: the pharmacist watched
/// a count type itself in and then vanish. Rather than direct the write at a
/// server that will not take it, the shelf's numbers are local facts now, and
/// the merge in `mergeMedicines` keeps them against every snapshot. The cost
/// is that counts and dates do not travel between devices; the catalogue
/// still does. Because there is no remote write, there is nothing to queue,
/// nothing to roll back and nothing that can refuse.
library;

import 'dart:async';

import '../models/medicine_model.dart';
import '../repositories/bundled_medicine_source.dart';
import '../repositories/medicine_store.dart';
import '../sync/pending_write_reporting.dart';
import '../sync/sync_status.dart';
import '../sync/sync_status_source.dart';
import 'medicine_cache.dart';
import 'medicine_merge.dart';
import 'medicine_row_codec.dart';

class SyncedMedicineStore
    implements MedicineStore, SyncStatusSource, DisposableStore {
  SyncedMedicineStore({
    required MedicineCache local,
    required MedicineStore remote,
    MedicineSource? bundled,
  })  : // A named parameter cannot be private, so `this._local` and
       // `this._remote` are not available and this is the only shape they
       // can take.
       // ignore: prefer_initializing_formals
       _local = local,
       // ignore: prefer_initializing_formals
       _remote = remote,
       _bundled = bundled ?? BundledMedicineSource();

  final MedicineCache _local;
  final MedicineStore _remote;
  final MedicineSource _bundled;

  Future<List<MedicineModel>>? _basePending;
  bool _seedAttempted = false;
  bool _disposed = false;

  /// What the last pump emitted, so a mirror that changes nothing costs no
  /// rebuild of every screen watching this provider.
  List<Map<String, dynamic>>? _lastEmitted;

  /// Serialized: a base read and a server snapshot can land within the same
  /// event loop turn, and two pumps running interleaved would merge against
  /// each other's inputs. Each pump waits for the one before it.
  Future<void> _pumpQueue = Future<void>.value();

  Future<List<MedicineModel>> _loadBase() =>
      _basePending ??= _local
          .loadAll()
          .catchError((Object _) => const <MedicineModel>[]);

  @override
  Stream<List<MedicineModel>> watchAll() {
    final controller = StreamController<List<MedicineModel>>();

    var base = const <MedicineModel>[];
    var remote = const <MedicineModel>[];

    /// A server failure held back until the local rows have been read, because
    /// whether it matters depends entirely on what they turn out to hold.
    Object? heldError;
    StackTrace? heldStack;

    /// Whether the server has answered at all, in either direction. An empty
    /// list before any answer is a question that has not been answered yet,
    /// not a catalogue the pharmacy stocks nothing of.
    var answered = false;

    /// The ids with unconfirmed local writes, read per pump so a confirmation
    /// is seen the moment the queue drops it.
    ///
    /// With medicine writes local-only nothing is queued to the server any
    /// more, so this reads empty in practice. It stays because the merge's
    /// protection rule asks for exactly this and one switch is cheaper than a
    /// second code path if a write ever queues again.
    Set<String> pendingIds() => switch (_remote) {
      final PendingWriteReporting reporting => reporting.pendingDocumentIds,
      _ => const <String>{},
    };

    void pump() {
      if (controller.isClosed || _disposed) return;
      // Anything to show makes the error moot. The error is about the server,
      // and the cache is the answer to it, so reporting it anyway would
      // replace a usable price list with a full-screen complaint.
      if (base.isNotEmpty) heldError = null;

      final merged = mergeMedicines(
        base: base,
        remote: remote,
        preferBaseIds: pendingIds(),
      );

      // Nothing to show and nothing to report yet: hold the event until one of
      // them arrives, rather than publishing an empty price list that reads as
      // a fact about the pharmacy's stock.
      if (merged.isEmpty && (heldError == null || !answered)) return;

      // Nothing to show but the server has spoken and said it could not be
      // reached: send the failure on its own. Publishing the empty list first
      // would put "no medicines in the price list" on screen for a frame,
      // which is a claim about the stock rather than a report that the price
      // list could not be read.
      if (merged.isEmpty) {
        controller.addError(heldError!, heldStack ?? StackTrace.current);
        heldError = null;
        return;
      }

      if (_differsFromLast(merged)) {
        _lastEmitted = _fingerprint(merged);
        controller.add(merged);
      }

      final error = heldError;
      if (error != null) {
        heldError = null;
        controller.addError(error, heldStack ?? StackTrace.current);
      }
    }

    /// Writes [merged] into the cache, skipping what is already stored.
    ///
    /// Errors are swallowed on purpose. A cache write that fails leaves the
    /// cache one snapshot behind, which the next snapshot corrects; raising
    /// the failure into the price list would punish the user for a disk that
    /// hiccuped once.
    Future<void> mirror(List<MedicineModel> merged) async {
      if (_disposed) return;
      try {
        final stored = await _local.loadAll();
        if (_disposed) return;
        final storedById = {
          for (final medicine in stored) medicine.documentId: medicine,
        };
        final changed = [
          for (final medicine in merged)
            if (!sameStoredMedicine(storedById[medicine.documentId], medicine))
              medicine,
        ];
        if (changed.isEmpty) return;
        await _local.upsertAll(changed);
      } catch (_) {
        // The next snapshot tries again; nothing the user typed is at risk,
        // because edits are written before any mirror runs.
      }
    }

    /// One pump per event, in order, and always against the cache as it
    /// stands *now*.
    ///
    /// The base is re-read rather than reusing the variable: an edit typed
    /// between snapshots lives only in the cache (writes are local-only), and
    /// a mirror from an earlier pump has moved rows since too. Merging against
    /// a base read at startup would silently drop the edit from the very list
    /// that claims to be showing it.
    void schedulePump() {
      _pumpQueue = _pumpQueue.then((_) async {
        if (_disposed) return;
        try {
          base = await _local.loadAll();
        } catch (_) {
          // Keep the previous base; the merge can still run on it.
        }
        await mirror(
          mergeMedicines(base: base, remote: remote, preferBaseIds: pendingIds()),
        );
        pump();
      });
    }

    // Read before the remote stream is wired up, so the base list and the
    // server's answer are gathered from the same moment rather than racing --
    // and so the seeding (which loadAll triggers on an empty database) is done
    // before any snapshot could be mirrored over it.
    final baseFuture = _loadBase();

    // Set before the first listen: a subscription cancelled while the base
    // read is still in flight must not leave the remote subscription alive
    // with nothing holding a reference to it.
    var remoteWired = false;
    late final StreamSubscription<List<MedicineModel>> remoteSubscription;
    controller.onCancel = () {
      if (remoteWired) unawaited(remoteSubscription.cancel());
    };

    controller.onListen = () {
      baseFuture.then((loaded) {
        if (controller.isClosed || _disposed) return;
        base = loaded;
        pump();

        remoteSubscription = _remote.watchAll().listen(
          (medicines) {
            remote = medicines;
            answered = true;
            unawaited(_seedIfEmpty(medicines));
            schedulePump();
          },
          onError: (Object error, StackTrace stackTrace) {
            // A failure is an answer: the server has spoken, and what it said
            // was that it could not be reached. Wait for the local rows before
            // deciding anything -- at the moment the error lands the base has
            // not been read, and the answer this store exists to avoid giving
            // is an empty price list.
            answered = true;
            heldError = error;
            heldStack = stackTrace;
            baseFuture.then(
              (_) => pump(),
              onError: (Object _, StackTrace _) => pump(),
            );
          },
        );
        remoteWired = true;
        // The listener may already have gone away while the base was loading.
        if (controller.isClosed) unawaited(remoteSubscription.cancel());
      }, onError: (Object error, StackTrace stackTrace) {
        // No local fallback at all: the server is the only hope, so this is
        // worth reporting rather than swallowing.
        if (!controller.isClosed) controller.addError(error, stackTrace);
      });
    };

    return controller.stream;
  }

  /// Whether [medicines] differs from what the last pump sent, compared field
  /// by field through the same fingerprints the mirror uses. The identity
  /// operator on [MedicineModel] compares name and price only, which would
  /// swallow a stock-count change and freeze the list.
  bool _differsFromLast(List<MedicineModel> medicines) {
    final previous = _lastEmitted;
    if (previous == null) return true;
    final next = _fingerprint(medicines);
    if (next.length != previous.length) return true;
    for (var i = 0; i < next.length; i++) {
      if (!_sameMap(next[i], previous[i])) return true;
    }
    return false;
  }

  static List<Map<String, dynamic>> _fingerprint(
    List<MedicineModel> medicines,
  ) {
    return [
      for (final medicine in medicines)
        {...medicineFingerprint(medicine), 'id': medicine.documentId},
    ];
  }

  static bool _sameMap(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Uploads the bundled catalogue when the collection is empty or every
  /// existing record already uses a product-ID identity.
  ///
  /// This replaces signing up and then running `tool/seed_firestore.dart` from
  /// a laptop, which was the only other way a new pharmacy ever got a price
  /// list and needed a connection to do it. The local cache is *not* consulted
  /// for this: an edit typed before the server was reachable must not become
  /// the server's first impression of a line the bundle prices at null stock.
  ///
  /// A non-empty legacy collection is left untouched. It has no product IDs to
  /// distinguish a new item from one a pharmacist deliberately removed, so
  /// automatically adding the new catalogue there could undo that decision.
  Future<void> _seedIfEmpty(List<MedicineModel> remoteRows) async {
    if (_seedAttempted) return;
    _seedAttempted = true;

    final base = await _bundled
        .load()
        .catchError((Object _) => const <MedicineModel>[]);
    if (_disposed || base.isEmpty) return;
    final isLegacyCollection = remoteRows.any(
      (medicine) => medicine.productId == null,
    );
    if (remoteRows.isNotEmpty && isLegacyCollection) return;

    final remoteIds = {for (final medicine in remoteRows) medicine.documentId};
    final missing = base
        .where((medicine) => !remoteIds.contains(medicine.documentId))
        .toList();
    if (missing.isEmpty) return;

    try {
      await _remote.upsertAll(missing);
    } catch (_) {
      // Offline, or refused. The cache already shows the list, and this is
      // offered again the next time the app starts.
    }
  }

  @override
  Future<void> setStock(MedicineModel medicine, int? stock) {
    // Local only. A count typed on the shelf is this device's fact: the server
    // write that used to follow landed on a rules refusal and rolled the edit
    // back out from under the pharmacist, so it is gone from the path. The
    // mirror keeps the value against every snapshot via `mergeMedicines`.
    return _local.setStock(medicine, stock);
  }

  @override
  Future<void> setExpiry(MedicineModel medicine, DateTime? expiry) {
    return _local.setExpiry(medicine, expiry);
  }

  @override
  Future<void> upsert(MedicineModel medicine) {
    return _local.upsert(medicine);
  }

  @override
  Future<void> upsertAll(Iterable<MedicineModel> medicines) {
    // Local only, like every medicine write. The server copy that used to ride
    // on the remote store's batches went with the server write path: an import
    // is this device's catalogue, and the one server-side write that remains
    // is the bundle seed in [_seedIfEmpty].
    return _local.upsertAll(medicines);
  }

  @override
  Stream<SyncStatus> watchSyncStatus() {
    // Passed straight through rather than restated, so the banner's view of
    // "can I reach the server" is exactly the remote store's. With medicine
    // writes local-only the remote queue stays empty, so the pending count it
    // reports reads zero and the banner measures reachability, not unsent
    // edits -- which is honest: nothing is waiting to be sent.
    return switch (_remote) {
      final SyncStatusSource source => source.watchSyncStatus(),
      // An inner store with no server behind it cannot be reached or missed,
      // so there is nothing here to report as offline.
      _ => Stream<SyncStatus>.value(SyncStatus.localOnly),
    };
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // The local cache is *not* disposed: it shares the app-scoped database
    // with the offline store and every store built after this one, so closing
    // it would be closing the door on the next signed-in account.
  }
}
