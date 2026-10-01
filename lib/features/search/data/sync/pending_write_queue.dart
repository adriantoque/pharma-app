import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A change this device has accepted but the server has not confirmed.
///
/// Firestore keeps its own queue of uncommitted writes and persists it to disk,
/// which covers the ordinary case of a write made offline and flushed later.
/// This record is the second copy, kept by the app, and it exists for the case
/// Firestore does not cover: the native store losing its persistence, or its
/// cache being evicted under the LRU budget, while a stock count the pharmacist
/// typed at the counter would otherwise be gone for good.
///
/// [fields] holds the merged document fields and nothing else -- no write
/// timestamp. `FieldValue.serverTimestamp()` is not a value and cannot be written
/// to storage, so the store stamps it afresh on every attempt. That is also the
/// correct behaviour: a replayed write should be dated when it landed rather
/// than when it was first typed.
@immutable
class PendingWrite {
  const PendingWrite({
    required this.id,
    required this.documentId,
    required this.fields,
    required this.queuedAt,
  });

  /// Assigned by the queue when the write is recorded, so it is unique for the
  /// life of the queue and stays unique across restarts.
  final String id;

  final String documentId;

  /// The fields to merge into the document. Every value has to be something
  /// `jsonEncode` accepts, which is why this is not simply the caller's map.
  final Map<String, dynamic> fields;

  final DateTime queuedAt;

  /// Stable across a save and a load, so an id recorded before a restart still
  /// matches after one.
  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'fields': fields,
    'queuedAt': queuedAt.millisecondsSinceEpoch,
  };

  /// Rebuilds a record read back from storage.
  ///
  /// Returns null for anything unusable rather than throwing. A stored queue is
  /// the one piece of state that outlives the process, so it is exactly the thing
  /// that meets an older version of this app, a truncated write, or a hand-edited
  /// preferences file. Dropping one unreadable entry is the right response: the
  /// alternative is a queue that can never drain, which would pin the banner's
  /// "changes not saved" message on screen permanently.
  static PendingWrite? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final documentId = json['documentId'];
    final fields = json['fields'];
    final queuedAt = json['queuedAt'];
    if (id is! String ||
        id.isEmpty ||
        documentId is! String ||
        documentId.isEmpty ||
        fields is! Map ||
        queuedAt is! int) {
      return null;
    }
    return PendingWrite(
      id: id,
      documentId: documentId,
      fields: Map<String, dynamic>.from(fields),
      queuedAt: DateTime.fromMillisecondsSinceEpoch(queuedAt),
    );
  }

  @override
  String toString() => 'PendingWrite($id -> $documentId $fields)';
}

/// The app's own record of what has not reached the server yet.
///
/// Separate from the store that writes, for the same reason `SyncStatusSource`
/// is a separate interface: the queue has a job of its own, does not care which
/// store is writing through it, and can be handed to a test as a list of records
/// without a database anywhere in sight.
abstract interface class PendingWriteQueue {
  /// Everything still unconfirmed, oldest first.
  ///
  /// An unmodifiable copy, not the live list. A caller takes one of these to
  /// decide which entries a snapshot has just confirmed, and it removes them
  /// asynchronously afterwards; handing out the live list would let that
  /// removal mutate the list being walked.
  List<PendingWrite> get pending;

  /// Reads whatever a previous run left behind.
  ///
  /// Call before trusting [pending]. Until it completes, [pending] is empty rather
  /// than unknown, which is the safe direction: a caller that sees an empty queue
  /// declines to act, and a caller that saw a half-read one might confirm writes
  /// it has not actually looked at.
  Future<void> read();

  /// Records [fields] as unconfirmed changes to [documentId] and returns what was
  /// stored, id included.
  Future<PendingWrite> add({
    required String documentId,
    required Map<String, dynamic> fields,
  });

  /// Forgets [ids]. Ids that are not waiting are ignored.
  ///
  /// One method rather than separate "confirmed" and "rejected" calls: both mean
  /// exactly the same thing to the queue -- stop carrying this -- and the
  /// difference between them belongs to the caller, which is the only place that
  /// knows why it is giving up.
  Future<void> remove(Iterable<String> ids);
}

/// Nothing queued is not a special case, and no implementation has to say so.
extension PendingWriteQueueCount on PendingWriteQueue {
  /// Whether anything is waiting.
  bool get isEmpty => pending.isEmpty;
}

/// A queue that holds its entries in memory only.
///
/// The default in tests and the fallback for a device where the stored copy could
/// not be opened. Entries are then lost when the process ends, which is the
/// behaviour that was already there before there was a queue at all -- so falling
/// back to it is a downgrade in durability and nothing else.
class InMemoryPendingWriteQueue implements PendingWriteQueue {
  final List<PendingWrite> _pending = [];
  var _nextId = 1;

  @override
  List<PendingWrite> get pending => List.unmodifiable(_pending);

  @override
  Future<void> read() async {}

  @override
  Future<PendingWrite> add({
    required String documentId,
    required Map<String, dynamic> fields,
  }) async {
    final write = PendingWrite(
      id: '${_nextId++}',
      documentId: documentId,
      fields: Map<String, dynamic>.from(fields),
      queuedAt: DateTime.now(),
    );
    _pending.add(write);
    return write;
  }

  @override
  Future<void> remove(Iterable<String> ids) async {
    final dropped = ids.toSet();
    _pending.removeWhere((write) => dropped.contains(write.id));
  }
}

/// A [PendingWriteQueue] that survives the app being closed.
///
/// Kept in preferences rather than a file of its own because the entries are a
/// few hundred bytes each and preferences is already a dependency on both
/// platforms this app ships to. It is also the wrong place for anything large:
/// [maxEntries] is a hard ceiling, because a device that is offline for a week
/// should not turn a key/value store into the app's biggest asset.
class StoredPendingWriteQueue implements PendingWriteQueue {
  StoredPendingWriteQueue({
    required Future<String?> Function() readStorage,
    required Future<void> Function(String value) writeStorage,
  }) : // A named parameter cannot be private, so `this._readStorage` is not
       // available and this is the only shape it can take.
       // ignore: prefer_initializing_formals
       _readStorage = readStorage,
       // ignore: prefer_initializing_formals
       _writeStorage = writeStorage;

  final Future<String?> Function() _readStorage;
  final Future<void> Function(String value) _writeStorage;

  final List<PendingWrite> _pending = [];

  /// Ids run on rather than restarting at 1 each launch, so an id recorded
  /// before a restart can never be handed out again -- which would make one
  /// write confirmable by another write's success.
  int _nextId = 1;

  bool _loaded = false;

  /// Every mutation goes through here, so two of them cannot interleave.
  ///
  /// Chained rather than guarded with a flag because the write path and the
  /// confirmation path are both asynchronous and both happen: a snapshot
  /// confirming a write and the user typing the next one land microseconds apart
  /// on a fast device. Serialising them means the second read-modify-write sees
  /// the first one's result instead of the state before it.
  Future<void> _chain = Future<void>.value();

  @override
  List<PendingWrite> get pending =>
      _loaded ? List.unmodifiable(_pending) : const <PendingWrite>[];

  @override
  Future<void> read() => _serialise(_load);

  Future<void> _load() async {
    if (_loaded) return;

    String? raw;
    try {
      raw = await _readStorage();
    } on Object {
      // Unreadable storage is an empty queue, not a failure. The writes still
      // reach Firestore through its own queue; all that is lost is the second
      // copy, and refusing to run would take the price list down with it.
      raw = null;
    }

    final decoded = _decode(raw);
    _pending
      ..clear()
      ..addAll(decoded.writes);
    _nextId = decoded.nextId;
    _loaded = true;
  }

  @override
  Future<PendingWrite> add({
    required String documentId,
    required Map<String, dynamic> fields,
  }) {
    // Declared rather than returned from inside the chain so the caller gets the
    // record without awaiting the storage write, which is the slow part. The
    // record is complete the moment it is created; only its durability waits.
    final write = PendingWrite(
      id: '${_nextId++}',
      documentId: documentId,
      fields: Map<String, dynamic>.from(fields),
      queuedAt: DateTime.now(),
    );
    return _serialise(() async {
      _pending.add(write);
      await _persist();
      return write;
    });
  }

  @override
  Future<void> remove(Iterable<String> ids) {
    final dropped = ids.toSet();
    if (dropped.isEmpty) return Future<void>.value();
    return _serialise(() async {
      _pending.removeWhere((write) => dropped.contains(write.id));
      await _persist();
    });
  }

  Future<T> _serialise<T>(Future<T> Function() operation) {
    final result = _chain.then((_) => operation());
    // The chain itself swallows failures, so one broken write cannot poison
    // every operation after it. The caller still sees its own error through
    // `result`.
    _chain = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _persist() async {
    // Oldest first, and capped from the newest end: if the ceiling is ever hit
    // it is a day-old count that gets dropped, not the one the pharmacist typed
    // thirty seconds ago.
    final kept = _pending.length > maxEntries
        ? _pending.sublist(_pending.length - maxEntries)
        : _pending;

    try {
      await _writeStorage(
        jsonEncode({
          'version': formatVersion,
          'nextId': _nextId,
          'writes': [for (final write in kept) write.toJson()],
        }),
      );
    } on Object {
      // Deliberately swallowed. A stock count that cannot be written to storage
      // has still been handed to Firestore and still goes out; failing here would
      // roll the optimistic update back and tell the pharmacist their count was
      // refused when it was not. What is lost is the backup copy, and the
      // Firestore queue is still behind it.
    }
  }

  /// Bumped if the stored shape ever changes. A version this class does not
  /// recognise is discarded rather than half-read, which is the same reasoning as
  /// dropping an unreadable entry: a queue that cannot drain is worse than no
  /// queue.
  static const int formatVersion = 1;

  /// Most entries kept. Far above what an hour at a counter produces, and small
  /// enough that the stored value stays a few tens of kilobytes.
  static const int maxEntries = 500;

  static ({List<PendingWrite> writes, int nextId}) _decode(String? raw) {
    if (raw == null || raw.isEmpty) return (writes: const [], nextId: 1);

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return (writes: const [], nextId: 1);
    }
    if (decoded is! Map) return (writes: const [], nextId: 1);
    if (decoded['version'] != formatVersion) return (writes: const [], nextId: 1);

    final entries = decoded['writes'];
    final writes = entries is List
        ? [
            // The null-aware element drops the unreadable ones rather than
            // failing the whole read: nine good entries are worth keeping even if
            // the tenth is something a newer build wrote.
            for (final entry in entries) ?PendingWrite.fromJson(entry),
          ]
        : const <PendingWrite>[];

    // Continues from the stored value, and never hands out an id that is already
    // waiting -- a duplicate id would let one write's confirmation discard
    // another's.
    final highest = writes.fold<int>(0, (max, write) {
      final parsed = int.tryParse(write.id);
      return parsed != null && parsed > max ? parsed : max;
    });
    final storedNext = decoded['nextId'];
    final nextId = storedNext is int && storedNext > highest ? storedNext : highest + 1;

    return (writes: writes, nextId: nextId);
  }
}