import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/connectivity/connection_source.dart';
import '../models/medicine_model.dart';
import '../sync/pending_write_queue.dart';
import '../sync/sync_status.dart';
import '../sync/sync_status_source.dart';
import '../sync/transport_failure.dart';
import 'medicine_store.dart';

/// The price list in Firestore, scoped to one signed-in user's account.
///
/// Everything is under `users/{uid}`, so two accounts never see each other's
/// catalogue and the security rules can be as simple as "you may only read and
/// write your own".
///
/// ## Where offline lives
///
/// Two independent signals, because they answer different questions and neither
/// is enough alone.
///
/// Firestore's stream is the authority on whether the *server* is reachable. A
/// captive portal or a wifi with no upstream still looks connected to the
/// platform, so nothing else can be trusted to notice that one.
///
/// [ConnectionSource] is the authority on how soon we find out. Firestore only
/// gives up after its own backoff, which is long, and until it does the app has
/// no reason to believe anything is wrong -- so the connection source is what
/// puts the banner up before Firestore would have.
///
/// ## What "it will sync later" rests on
///
/// [PendingWriteQueue]. Firestore queues writes while offline and persists that
/// queue itself, which handles a write made offline in this process. The queue
/// here is the second copy, and it is what makes the banner's promise survive the
/// cases Firestore's own persistence does not: the app being killed mid-queue, or
/// the native cache being evicted under its LRU budget. Entries are put back on
/// the wire when the connection returns, or when the app next starts with one
/// already waiting.
class FirestoreMedicineStore
    implements MedicineStore, SyncStatusSource, DisposableStore {
  FirestoreMedicineStore({
    required FirebaseFirestore firestore,
    required String uid,
    required this._queue,
    this._connection,
  }) : _firestore = firestore,
       _collection = firestore
           .collection('users')
           .doc(uid)
           .collection('medicines') {
    _connectionSubscription = _connection?.watch().listen(_onConnectionChanged);
    // Started here rather than at the first snapshot: a queued write left over
    // from a previous run has to go out before the stream reports itself clean,
    // or that snapshot would confirm writes nothing had actually sent.
    unawaited(_restore());
  }

  final FirebaseFirestore _firestore;
  final CollectionReference<Map<String, dynamic>> _collection;
  final PendingWriteQueue _queue;
  final ConnectionSource? _connection;

  StreamSubscription<bool>? _connectionSubscription;

  /// Firestore's own timestamp for the write side, re-created per attempt because
  /// a sentinel is consumed by the write it is given to.
  FieldValue _serverTimestamp() => FieldValue.serverTimestamp();

  final StreamController<SyncStatus> _sync =
      StreamController<SyncStatus>.broadcast();

  /// The last thing measured, so a listener subscribing late is told where
  /// things stand instead of waiting for a change that may never come offline.
  SyncStatus _status = SyncStatus.unknown;

  /// What the Firestore stream has said, before the platform's opinion is folded
  /// into it. Kept apart from [_status] because the two have to be weighed
  /// against each other on every change, and collapsing them into one field would
  /// lose whichever one lost.
  Reachability _serverReachability = Reachability.unknown;

  /// Null until the platform answers. Never "not connected" as a starting value:
  /// the app knows nothing about the network at launch, and starting pessimistic
  /// would flash an offline banner at somebody who is standing in a pharmacy with
  /// a working connection.
  bool? _platformConnected;

  DateTime? _lastServerReadTime;

  /// Entries handed to Firestore that have not been seen acknowledged.
  ///
  /// This is what makes confirmation honest. A queue entry that has not been put
  /// on the wire cannot be confirmed by a snapshot that came back clean, however
  /// plausible that looks -- which is the exact case the queue exists for, where
  /// Firestore has lost the write and only the app still has it.
  final Set<String> _onWire = {};

  bool _disposed = false;

  @override
  Stream<List<MedicineModel>> watchAll() {
    return _collection
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          _noteSnapshot(snapshot);
          return _toList(snapshot);
        })
        .transform(
          StreamTransformer<List<MedicineModel>, List<MedicineModel>>.fromHandlers(
            // Records the loss of contact and passes the error on unchanged. The
            // offline store decides whether it is fatal; all this can honestly
            // say is that nothing arrived.
            handleError: (error, stackTrace, sink) {
              _noteError(error);
              sink.addError(error, stackTrace);
            },
          ),
        );
  }

  @override
  Stream<SyncStatus> watchSyncStatus() async* {
    yield _status;
    yield* _sync.stream;
  }

  /// Puts anything a previous run left in the queue back on the wire.
  Future<void> _restore() async {
    await _queue.read();
    if (_disposed) return;
    await _replayPending();
    _recompute();
  }

  /// Everything a snapshot says, in one place.
  ///
  /// A snapshot that arrives at all means the connection works, whatever the
  /// writes riding along with it say.
  void _noteSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final metadata = snapshot.metadata;

    // Stamped rather than read off the snapshot: the Dart client does not carry
    // Firestore's server read time, and the local clock is the only honest
    // answer. Only advanced for a snapshot that came off the wire, so a cache
    // replay while offline cannot claim a fresh read.
    if (metadata.isFromCache) return;

    _serverReachability = Reachability.online;
    _lastServerReadTime = DateTime.now();

    if (metadata.hasPendingWrites) return;

    // Everything on the wire has been acknowledged. The list is taken now, not
    // when the removal runs, so a write issued in between is still waiting when
    // the removal happens.
    final confirmed = [
      for (final write in _queue.pending)
        if (_onWire.contains(write.id)) write.id,
    ];
    if (confirmed.isEmpty) return;

    _onWire.removeAll(confirmed);
    unawaited(_queue.remove(confirmed));
  }

  /// What a failed read means.
  ///
  /// Only a transport failure counts as offline. A missing database or a
  /// permission problem is not a dead connection and will still be there when
  /// the signal comes back, so reporting those as offline would promise the user
  /// a fix that is not going to arrive.
  ///
  /// Anything already recorded as pending stays recorded: a failed read says
  /// nothing about whether writes are still outstanding, and clearing the count
  /// would claim they had landed.
  void _noteError(Object error) {
    if (isTransportFailure(error)) {
      _serverReachability = Reachability.offline;
      _recompute();
    }
  }

  /// The platform's view of the network, folded in with Firestore's.
  ///
  /// Firestore wins a disagreement. It has actually spoken to the server and come
  /// back empty-handed, where the platform has merely noticed an interface went
  /// down -- and a device that dropped its wifi moments after a dead connection
  /// is the ordinary case, not an exception.
  Reachability _resolveReachability() {
    if (_serverReachability == Reachability.offline) {
      return Reachability.offline;
    }
    if (_platformConnected == false) return Reachability.offline;
    return _serverReachability;
  }

  void _recompute() {
    _report(
      SyncStatus(
        reachability: _resolveReachability(),
        pendingWriteCount: _queue.pending.length,
        lastServerReadTime: _lastServerReadTime,
      ),
    );
  }

  void _report(SyncStatus status) {
    if (_status == status) return;
    _status = status;
    if (_disposed || _sync.isClosed) return;
    _sync.add(status);
  }

  /// What the platform said about the network.
  void _onConnectionChanged(bool connected) {
    if (_disposed) return;
    _platformConnected = connected;

    // Whether the banner comes down is not decided here: Firestore has not
    // answered yet, so it is still offline as far as anyone knows, and the
    // snapshot [_resume] provokes is what will change that.
    _recompute();
    if (connected) unawaited(_resume());
  }

  /// Everything still queued, in the order it was typed.
  ///
  /// In order because it is the order the user meant. Replaying a stock count of
  /// five after a count of nine would leave the shelf showing five, which is a
  /// wrong answer rather than a late one.
  Future<void> _replayPending() async {
    for (final write in _queue.pending) {
      if (_disposed) return;
      if (_onWire.contains(write.id)) continue;
      try {
        await _apply(write);
      } on Object {
        // Left in the queue, on purpose: it is still correct and still waiting,
        // and the next reconnect or restart will try again. A write that the
        // server actually refused is dropped instead, in [_submit].
        break;
      }
    }
  }

  Future<void> _resume() async {
    // Replayed before the network is enabled, not after. Firestore marks its
    // local store pending the moment a write is handed to it, and a clean server
    // snapshot that landed in between would confirm a queue of writes that had
    // never left the device.
    await _replayPending();
    if (_disposed) return;
    await _firestore.enableNetwork();
    _platformConnected = true;
    _recompute();
  }

  /// Records a change, tries it, and keeps it until the server says otherwise.
  ///
  /// The future resolves as soon as the write has been handed over, which is what
  /// the provider's optimistic update needs, and the entry stays in the queue
  /// until a snapshot confirms it. A write the server *refuses* is the one case
  /// that rethrows: nothing is going to change its mind, so the caller has to
  /// take its optimistic update back.
  Future<void> _submit({
    required String documentId,
    required Map<String, dynamic> fields,
  }) async {
    final write = await _queue.add(documentId: documentId, fields: fields);
    _recompute();

    try {
      await _apply(write);
      _recompute();
    } on Object catch (error, stackTrace) {
      if (!isTransportFailure(error)) {
        _onWire.remove(write.id);
        await _queue.remove([write.id]);
        _recompute();
        Error.throwWithStackTrace(error, stackTrace);
      }
      // Undeliverable rather than refused. Left in the queue for the next
      // attempt; the caller does not hear about it, because the write is not lost
      // and the banner is what says so.
    }
  }

  /// Hands one recorded change to Firestore.
  Future<void> _apply(PendingWrite write) async {
    await _collection.doc(write.documentId).set({
      ...write.fields,
      'updatedAt': _serverTimestamp(),
    }, SetOptions(merge: true));
    _onWire.add(write.id);
  }

  /// Documents as a sorted, immutable list.
  ///
  /// Ordered here rather than asked of Firestore so the order is the same one
  /// the in-memory list uses. A compound `orderBy` would need a composite index
  /// for every additional sort, and a price list of a few hundred lines is small
  /// enough to order in memory.
  static List<MedicineModel> _toList(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final medicines = [
      for (final document in snapshot.docs)
        MedicineModel.fromFirestore(document.data()),
    ]..sort(MedicineModel.compareByNameThenPrice);
    return List.unmodifiable(medicines);
  }

  @override
  Future<void> setStock(MedicineModel medicine, int? stock) {
    // Only the count. Writing the whole document here would let a count typed
    // on the inventory screen overwrite a price or an expiry that was just
    // corrected, because the widget is holding a copy from before.
    return _submit(
      documentId: medicine.documentId,
      fields: {'stock': stock},
    );
  }

  @override
  Future<void> setExpiry(MedicineModel medicine, DateTime? expiry) {
    return _submit(
      documentId: medicine.documentId,
      fields: {'expiryDate': MedicineModel.formatExpiry(expiry)},
    );
  }

  @override
  Future<void> upsert(MedicineModel medicine) {
    return _submit(
      documentId: medicine.documentId,
      fields: medicine.toFirestore(),
    );
  }

  @override
  Future<void> upsertAll(Iterable<MedicineModel> medicines) async {
    final batch = _firestore.batch();
    var pending = 0;

    for (final medicine in medicines) {
      batch.set(
        _collection.doc(medicine.documentId),
        {...medicine.toFirestore(), 'updatedAt': _serverTimestamp()},
      );
      // Firestore caps a batch at 500 writes, and an import is several hundred
      // documents, so this is a limit that is actually reached rather than a
      // theoretical one. Overflow is committed and the batch starts again.
      if (++pending == _batchLimit) {
        await batch.commit();
        pending = 0;
      }
    }

    if (pending > 0) await batch.commit();
    // Deliberately not queued entry by entry. This is a bulk import of several
    // hundred lines, it is the one write that is safe to lose if it is refused,
    // and reading it back out of storage would cost more than the durability it
    // bought: Firestore's own batch queue already holds it if the device is
    // offline, and a re-run of the import is a single tap away. What this does
    // still do is recompute, so an import made offline leaves the banner saying
    // so rather than reporting the catalogue as saved.
    _recompute();
  }

  static const int _batchLimit = 500;

  @override
  void dispose() {
    // Tolerates a second call, because the offline store disposes what it wraps
    // and its own owner may have disposed the same store directly.
    if (_disposed) return;
    _disposed = true;
    unawaited(_connectionSubscription?.cancel());
    unawaited(_sync.close());
  }
}