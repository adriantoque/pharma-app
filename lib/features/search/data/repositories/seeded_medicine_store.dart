import 'dart:async';

import '../models/medicine_model.dart';
import '../sync/sync_status.dart';
import '../sync/sync_status_source.dart';
import 'bundled_medicine_source.dart';
import 'medicine_store.dart';

/// A price list that works with no connection at all.
///
/// Wraps a real store and a bundled price list, and serves whichever of the two it
/// has. The bundled list goes out first, before any network call has finished, so
/// the catalogue is on screen immediately; the server's answer then merges over
/// it and takes over.
///
/// The merge is by [MedicineModel.documentId] rather than replacing one list with
/// the other. A line the server knows about wins, so a stock count typed at the
/// counter is never overwritten by the bundled copy of the same product; a line
/// only the bundle has is still shown, which is what keeps a newly created
/// account from looking empty.
///
/// Nothing here is a second source of truth. Writes go straight to the inner
/// store, and the local echo of an offline write comes back through its snapshot
/// stream like any other change -- Firestore queues the write and reports it
/// locally, so no overlay has to be invented or kept in step by hand.
class SeededMedicineStore
    implements MedicineStore, SyncStatusSource, DisposableStore {
  SeededMedicineStore({
    required MedicineStore remote,
    MedicineSource? bundled,
  }) : // A named parameter cannot be private, so `this._remote` is not
       // available and this is the only shape it can take.
       // ignore: prefer_initializing_formals
       _remote = remote,
       _bundled = bundled ?? BundledMedicineSource();

  final MedicineStore _remote;
  final MedicineSource _bundled;

  Future<List<MedicineModel>>? _basePending;
  bool _seedAttempted = false;
  bool _disposed = false;

  /// The bundled list, read once. A second read would decode the asset again for
  /// the same answer.
  Future<List<MedicineModel>> _loadBase() =>
      _basePending ??= _bundled.load().catchError((Object _) => const <MedicineModel>[]);

  @override
  Stream<List<MedicineModel>> watchAll() {
    final controller = StreamController<List<MedicineModel>>();

    var base = const <MedicineModel>[];
    var remote = const <MedicineModel>[];

    /// A server failure held back until the bundled list has been read, because
    /// whether it matters depends entirely on what the bundle turns out to say.
    Object? heldError;
    StackTrace? heldStack;

    /// Whether the server has answered at all, in either direction.
    ///
    /// An empty list before any answer is not an empty catalogue, it is a question
    /// that has not been answered yet. Emitting one would show "no medicines" for a
    /// frame on every launch, which reads as a claim about the pharmacy's stock.
    var answered = false;

    void pump() {
      if (controller.isClosed) return;
      // Anything to show makes the error moot. The error is about the server, and
      // the bundle is the answer to it, so reporting it anyway would replace a
      // usable price list with a full-screen complaint.
      if (base.isNotEmpty) heldError = null;

      final merged = _merge(base, remote);

      // Nothing to show and nothing to report yet: hold the event until one of
      // them arrives, rather than publishing an empty price list that reads as a
      // fact about the pharmacy's stock.
      if (merged.isEmpty && (heldError == null || !answered)) return;

      // Nothing to show but the server has spoken and said it could not be
      // reached: send the failure on its own. Publishing the empty list first
      // would put "no medicines in the price list" on screen for a frame, which is
      // a claim about the pharmacy's stock rather than a report that the price
      // list could not be read.
      if (merged.isEmpty) {
        controller.addError(heldError!, heldStack ?? StackTrace.current);
        heldError = null;
        return;
      }

      controller.add(merged);

      final error = heldError;
      if (error != null) {
        heldError = null;
        controller.addError(error, heldStack ?? StackTrace.current);
      }
    }

    // Read before either stream is wired up, so the base list and the server's
    // answer are being gathered from the same moment rather than racing.
    final baseFuture = _loadBase();

    baseFuture.then((loaded) {
      base = loaded;
      pump();
    }, onError: (Object error, StackTrace stackTrace) {
      // No fallback at all, so the caller does need to hear about it -- but only
      // if the server has nothing either.
      if (remote.isEmpty && !controller.isClosed) {
        controller.addError(error, stackTrace);
      }
    });

    // Local rather than a field: two callers watching at once each need their own
    // subscription to cancel, and a shared one would leave the first listener's
    // subscription alive with nothing holding a reference to it.
    late final StreamSubscription<List<MedicineModel>> remoteSubscription;

    controller.onListen = () {
      remoteSubscription = _remote.watchAll().listen(
        (medicines) {
          remote = medicines;
          answered = true;
          unawaited(_seedIfEmpty(medicines));
          pump();
        },
        onError: (Object error, StackTrace stackTrace) {
          // A failure is an answer: the server has spoken, and what it said was
          // that it could not be reached.
          answered = true;
          heldError = error;
          heldStack = stackTrace;
          // Wait for the bundled list before deciding anything. At the moment the
          // error lands the base has not been read, and the answer this store
          // exists to avoid giving is an empty price list.
          baseFuture.then((_) => pump(), onError: (_) => pump());
        },
      );
    };

    controller.onCancel = () => unawaited(remoteSubscription.cancel());

    return controller.stream;
  }

  /// The bundled list with the server's answer laid over it.
  static List<MedicineModel> _merge(
    List<MedicineModel> base,
    List<MedicineModel> remote,
  ) {
    if (remote.isEmpty) return List.unmodifiable(base);
    if (base.isEmpty) return List.unmodifiable(remote);

    final byId = <String, MedicineModel>{
      for (final medicine in base) medicine.documentId: medicine,
    };
    for (final medicine in remote) {
      byId[medicine.documentId] = medicine;
    }

    final merged = byId.values.toList()
      ..sort(MedicineModel.compareByNameThenPrice);
    return List.unmodifiable(merged);
  }

/// Uploads the bundled price list the first time the shared collection is found empty.
///
/// This replaces signing up and then running `tool/seed_firestore.dart` from a
/// laptop, which was the only other way a new pharmacy ever got a price list and
/// needed a connection to do it.
///
/// If the shared collection already has lines (added by another user), it is left
/// alone: putting the bundled list back would undo edits the pharmacist made.
Future<void> _seedIfEmpty(List<MedicineModel> remote) async {
  if (_seedAttempted) return;
  _seedAttempted = true;
  if (remote.isNotEmpty) return;

  final base = await _loadBase();
  if (_disposed || base.isEmpty) return;

  try {
    await _remote.upsertAll(base);
  } catch (_) {
    // Offline, or refused. The bundled list is already on screen, and this is
    // offered again the next time the app starts.
  }
}

  @override
  Stream<SyncStatus> watchSyncStatus() {
    // Passed straight through rather than restated, so the offline store's view of
    // "can I reach the server" is exactly the inner store's.
    return switch (_remote) {
      final SyncStatusSource source => source.watchSyncStatus(),
      // An inner store with no server behind it cannot be reached or missed, so
      // there is nothing here to report as offline.
      _ => Stream<SyncStatus>.value(SyncStatus.localOnly),
    };
  }

  @override
  Future<void> setStock(MedicineModel medicine, int? stock) =>
      _remote.setStock(medicine, stock);

  @override
  Future<void> setExpiry(MedicineModel medicine, DateTime? expiry) =>
      _remote.setExpiry(medicine, expiry);

  @override
  Future<void> upsert(MedicineModel medicine) => _remote.upsert(medicine);

  @override
  Future<void> upsertAll(Iterable<MedicineModel> medicines) =>
      _remote.upsertAll(medicines);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Only when the inner store wants releasing. A store handed in by a test may be
    // owned by the test, and disposing something the caller still holds would be
    // its bug to find.
    switch (_remote) {
      case final DisposableStore disposable:
        disposable.dispose();
      case _:
        break;
    }
  }
}