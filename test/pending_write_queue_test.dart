import 'dart:convert';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/search/data/sync/pending_write_queue.dart';
import 'package:pharmaguide/features/search/data/sync/transport_failure.dart';

/// A storage double for [StoredPendingWriteQueue].
///
/// Stands in for the SharedPreferences string it is wired to in `main.dart`, so
/// the queue can be exercised across a restart -- the whole point of the stored
/// implementation -- without a device or a plugin.
class _FakeStorage {
  _FakeStorage([this.value]);

  String? value;

  /// Set to make every write fail, as a full disk would.
  Object? writeError;

  int writes = 0;

  Future<String?> read() async => value;

  Future<void> write(String next) async {
    writes++;
    if (writeError != null) throw writeError!;
    value = next;
  }
}

StoredPendingWriteQueue _queueOver(_FakeStorage storage) =>
    StoredPendingWriteQueue(
      readStorage: storage.read,
      writeStorage: storage.write,
    );

Map<String, dynamic> decode(String? raw) =>
    jsonDecode(raw!) as Map<String, dynamic>;

void main() {
  group('PendingWrite', () {
    test('survives a save and a load', () {
      final write = PendingWrite(
        id: '7',
        documentId: 'abc123',
        fields: const {'stock': 12},
        queuedAt: DateTime.fromMillisecondsSinceEpoch(1712000000000),
      );

      final restored = PendingWrite.fromJson(
        jsonDecode(jsonEncode(write.toJson())),
      );

      expect(restored, isNotNull);
      expect(restored!.id, '7');
      expect(restored.documentId, 'abc123');
      expect(restored.fields, {'stock': 12});
      expect(restored.queuedAt, write.queuedAt);
    });

    test('reads back nothing rather than throwing on an unusable record', () {
      // A stored queue is the one piece of state that outlives the process, so it
      // is exactly the thing that meets a truncated write or a hand-edited
      // preferences file. Dropping the entry is what keeps a queue that can never
      // drain -- and the banner that would then never come down -- from happening.
      expect(PendingWrite.fromJson(null), isNull);
      expect(PendingWrite.fromJson('a string'), isNull);
      expect(PendingWrite.fromJson(const <dynamic>[]), isNull);
      expect(PendingWrite.fromJson(const {'id': '1'}), isNull);
      expect(
        PendingWrite.fromJson(const {
          'id': '',
          'documentId': 'abc',
          'fields': <String, dynamic>{},
          'queuedAt': 0,
        }),
        isNull,
        reason: 'an empty id is not a usable key',
      );
      expect(
        PendingWrite.fromJson(const {
          'id': '1',
          'documentId': 'abc',
          'fields': 'not a map',
          'queuedAt': 0,
        }),
        isNull,
      );
      expect(
        PendingWrite.fromJson(const {
          'id': '1',
          'documentId': 'abc',
          'fields': <String, dynamic>{},
          'queuedAt': 'not an int',
        }),
        isNull,
      );
    });
  });

  group('InMemoryPendingWriteQueue', () {
    test(
      'records writes with unique ids and hands back an unmodifiable list',
      () async {
        final queue = InMemoryPendingWriteQueue();

        expect(queue.isEmpty, isTrue);

        final first = await queue.add(
          documentId: 'abc',
          fields: const {'stock': 1},
        );
        final second = await queue.add(
          documentId: 'abc',
          fields: const {'stock': 2},
        );

        expect(first.id, isNot(second.id));
        expect(queue.pending.map((w) => w.documentId), ['abc', 'abc']);
        expect(() => queue.pending.add(first), throwsUnsupportedError);
      },
    );

    test('forgets the ids it is given and ignores the rest', () async {
      final queue = InMemoryPendingWriteQueue();
      final first = await queue.add(
        documentId: 'a',
        fields: const {'stock': 1},
      );
      await queue.add(documentId: 'b', fields: const {'stock': 2});

      await queue.remove([first.id, 'an id that was never issued']);

      expect(queue.pending.map((w) => w.documentId), ['b']);
    });

    test(
      'copies the fields so a later edit by the caller cannot rewrite history',
      () async {
        final queue = InMemoryPendingWriteQueue();
        final fields = <String, dynamic>{'stock': 1};

        final write = await queue.add(documentId: 'a', fields: fields);
        fields['stock'] = 999;

        expect(write.fields, {'stock': 1});
        expect(queue.pending.single.fields, {'stock': 1});
      },
    );
  });

  group('StoredPendingWriteQueue, recording', () {
    test('holds nothing until the stored copy has been read', () async {
      final storage = _FakeStorage(
        jsonEncode({
          'version': StoredPendingWriteQueue.formatVersion,
          'nextId': 2,
          'writes': [
            {
              'id': '1',
              'documentId': 'abc',
              'fields': {'stock': 12},
              'queuedAt': 1712000000000,
            },
          ],
        }),
      );
      final queue = _queueOver(storage);

      expect(
        queue.pending,
        isEmpty,
        reason:
            'an empty queue is the safe thing to show before a read: a caller '
            'that sees it declines to confirm anything',
      );

      await queue.read();

      expect(queue.pending.single.documentId, 'abc');
      expect(queue.pending.single.fields, {'stock': 12});
    });

    test('persists each write as it is accepted', () async {
      final storage = _FakeStorage();
      final queue = _queueOver(storage);
      await queue.read();

      await queue.add(documentId: 'abc', fields: const {'stock': 12});

      final stored = decode(storage.value);
      expect(stored['version'], StoredPendingWriteQueue.formatVersion);
      expect(stored['nextId'], 2);
      expect(stored['writes'], hasLength(1));
      expect((stored['writes'] as List).single, {
        'id': '1',
        'documentId': 'abc',
        'fields': {'stock': 12},
        'queuedAt': isA<int>(),
      });
    });

    test(
      'keeps only the fields it was given, never a write timestamp',
      () async {
        // A server timestamp is not a storable value, and a replayed write should be
        // dated when it landed rather than when it was first typed -- so `fields` is
        // everything but the stamp, and the store adds that per attempt.
        final storage = _FakeStorage();
        final queue = _queueOver(storage);
        await queue.read();

        await queue.add(documentId: 'abc', fields: const {'stock': 12});

        final fields =
            (decode(storage.value)['writes'] as List).single['fields'];
        expect(fields, {'stock': 12});
      },
    );

    test('hands the record back before the storage write has landed', () async {
      final storage = _FakeStorage();
      final queue = _queueOver(storage);
      await queue.read();

      final write = await queue.add(
        documentId: 'abc',
        fields: const {'stock': 12},
      );

      // The record is complete the moment it is created; only its durability
      // waits on storage. A slow preferences write must not delay the row
      // repainting on screen.
      expect(write.id, '1');
      expect(queue.pending.single.id, '1');
    });

    test('two writes landing together are both recorded', () async {
      // A snapshot confirming a write and the user typing the next one land
      // microseconds apart on a fast device. Serialising them is what stops the
      // second read-modify-write from persisting over the first.
      final storage = _FakeStorage();
      final queue = _queueOver(storage);
      await queue.read();

      final results = await Future.wait([
        queue.add(documentId: 'a', fields: const {'stock': 1}),
        queue.add(documentId: 'b', fields: const {'stock': 2}),
        queue.add(documentId: 'c', fields: const {'stock': 3}),
      ]);

      expect(queue.pending.map((w) => w.documentId), ['a', 'b', 'c']);
      expect(results.map((w) => w.id).toSet(), hasLength(3));
      expect(decode(storage.value)['writes'], hasLength(3));
    });
  });

  group('StoredPendingWriteQueue, forgetting', () {
    test('removes the named writes and persists the shorter queue', () async {
      final storage = _FakeStorage();
      final queue = _queueOver(storage);
      await queue.read();
      final first = await queue.add(
        documentId: 'a',
        fields: const {'stock': 1},
      );
      await queue.add(documentId: 'b', fields: const {'stock': 2});

      await queue.remove([first.id]);

      expect(queue.pending.map((w) => w.documentId), ['b']);
      expect(decode(storage.value)['writes'], hasLength(1));
    });

    test('does not touch storage when given nothing to forget', () async {
      final storage = _FakeStorage();
      final queue = _queueOver(storage);
      await queue.read();
      await queue.add(documentId: 'a', fields: const {'stock': 1});
      final before = storage.writes;

      await queue.remove([]);

      expect(storage.writes, before);
    });
  });

  group('StoredPendingWriteQueue, unreadable storage', () {
    test('a malformed payload is an empty queue, not a failure', () async {
      for (final raw in ['not json at all', '"a bare string"', '[]', '{']) {
        final queue = _queueOver(_FakeStorage(raw));

        await queue.read();

        expect(queue.pending, isEmpty, reason: 'for payload: $raw');
      }
    });

    test('a payload from another version is discarded whole', () async {
      final storage = _FakeStorage(
        jsonEncode({
          'version': StoredPendingWriteQueue.formatVersion + 1,
          'nextId': 9,
          'writes': [
            {
              'id': '1',
              'documentId': 'abc',
              'fields': <String, dynamic>{},
              'queuedAt': 0,
            },
          ],
        }),
      );
      final queue = _queueOver(storage);

      await queue.read();

      expect(queue.pending, isEmpty);
    });

    test('one unreadable entry does not cost the readable ones', () async {
      // Nine good entries are worth keeping even if the tenth is something a
      // newer build wrote.
      final storage = _FakeStorage(
        jsonEncode({
          'version': StoredPendingWriteQueue.formatVersion,
          'nextId': 99,
          'writes': [
            {'id': '1', 'documentId': 'a', 'fields': {}, 'queuedAt': 0},
            {'id': '2', 'documentId': 'no fields', 'queuedAt': 0},
            {'id': '3', 'documentId': 'c', 'fields': {}, 'queuedAt': 0},
          ],
        }),
      );
      final queue = _queueOver(storage);

      await queue.read();

      expect(queue.pending.map((w) => w.documentId), ['a', 'c']);
    });

    test('a storage read that throws costs the backup copy and nothing else', () async {
      // The writes still reach Firestore through its own queue. Refusing to run
      // would take the whole price list down for the sake of a second copy.
      final storage = _FakeStorage();
      final queue = StoredPendingWriteQueue(
        readStorage: () async => throw StateError('preferences unavailable'),
        writeStorage: storage.write,
      );

      await queue.read();

      expect(queue.pending, isEmpty);

      final write = await queue.add(
        documentId: 'abc',
        fields: const {'stock': 12},
      );

      expect(queue.pending.single.id, write.id);
    });

    test('a storage write that throws does not refuse the write', () async {
      // The count has already gone to Firestore; failing here would roll the
      // optimistic update back and tell the pharmacist their count was refused
      // when it was not.
      final storage = _FakeStorage()..writeError = StateError('disk full');
      final queue = _queueOver(storage);
      await queue.read();

      final write = await queue.add(
        documentId: 'abc',
        fields: const {'stock': 12},
      );

      expect(write.id, '1');
      expect(queue.pending.single.documentId, 'abc');
    });

    test('a failed persist does not poison the writes that follow', () async {
      final storage = _FakeStorage();
      final queue = _queueOver(storage);
      await queue.read();

      storage.writeError = StateError('disk full');
      await queue.add(documentId: 'a', fields: const {'stock': 1});

      storage.writeError = null;
      await queue.add(documentId: 'b', fields: const {'stock': 2});

      expect(queue.pending.map((w) => w.documentId), ['a', 'b']);
      // The recovered write persists both entries: the earlier one is still
      // waiting, so the stored copy is whole again.
      expect(decode(storage.value)['writes'], hasLength(2));
    });
  });

  group('StoredPendingWriteQueue, across a restart', () {
    test('brings back what the previous run left behind', () async {
      final storage = _FakeStorage();
      final before = _queueOver(storage);
      await before.read();
      await before.add(documentId: 'abc', fields: const {'stock': 12});
      await before.add(documentId: 'def', fields: const {'stock': 3});

      final after = _queueOver(storage);
      await after.read();

      expect(after.pending.map((w) => w.documentId), ['abc', 'def']);
      expect(after.pending.map((w) => w.fields), [
        {'stock': 12},
        {'stock': 3},
      ]);
    });

    test('never hands out an id a previous run already used', () async {
      // A repeated id would let one write's confirmation discard another's.
      final storage = _FakeStorage();
      final before = _queueOver(storage);
      await before.read();
      await before.add(documentId: 'a', fields: const {'stock': 1});
      await before.add(documentId: 'b', fields: const {'stock': 2});
      await before.remove([(before.pending.last).id]);

      final after = _queueOver(storage);
      await after.read();
      final reused = await after.add(
        documentId: 'c',
        fields: const {'stock': 3},
      );

      expect(reused.id, '3');
      expect(after.pending.map((w) => w.id), ['1', '3']);
    });

    test('trusts the entries over the stored counter', () async {
      // A truncated or hand-edited file can carry a counter behind the entries it
      // holds. The next id has to clear the highest one actually waiting.
      final storage = _FakeStorage(
        jsonEncode({
          'version': StoredPendingWriteQueue.formatVersion,
          'nextId': 1,
          'writes': [
            {'id': '41', 'documentId': 'a', 'fields': {}, 'queuedAt': 0},
          ],
        }),
      );
      final queue = _queueOver(storage);

      await queue.read();

      expect((await queue.add(documentId: 'b', fields: const {})).id, '42');
    });

    test('is unchanged by a read that has already happened', () async {
      final storage = _FakeStorage();
      final queue = _queueOver(storage);
      await queue.read();
      await queue.add(documentId: 'a', fields: const {'stock': 1});

      await queue.read();

      expect(queue.pending, hasLength(1));
    });
  });

  group('StoredPendingWriteQueue, the ceiling', () {
    test('drops the oldest entries rather than the newest', () async {
      final storage = _FakeStorage();
      final queue = _queueOver(storage);
      await queue.read();

      for (var i = 0; i < StoredPendingWriteQueue.maxEntries + 1; i++) {
        await queue.add(documentId: 'doc$i', fields: const {'stock': 1});
      }

      final stored = (decode(storage.value)['writes'] as List)
          .cast<Map<String, dynamic>>();
      expect(stored, hasLength(StoredPendingWriteQueue.maxEntries));
      expect(
        stored.first['documentId'],
        'doc1',
        reason: 'the count a pharmacist typed thirty seconds ago outranks a day-old one',
      );
      expect(
        stored.last['documentId'],
        'doc${StoredPendingWriteQueue.maxEntries}',
      );
      expect(
        queue.pending,
        hasLength(StoredPendingWriteQueue.maxEntries + 1),
        reason: 'the ceiling applies to what is kept, not to what is in hand',
      );
    });
  });

  group('isTransportFailure', () {
    FirebaseException firebase(String code) =>
        FirebaseException(plugin: 'cloud_firestore', code: code);

    test('recognises the failures a lost connection actually produces', () {
      for (final code in [
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
      ]) {
        expect(isTransportFailure(firebase(code)), isTrue, reason: code);
      }
    });

    test('does not report a refusal as a lost connection', () {
      // Coming back online will not fix a denied permission or a missing
      // database, and a banner that claims otherwise keeps asking the pharmacist
      // to check a network that is already up. Retrying forever would also fill
      // the queue with something that can never land.
      for (final code in [
        'permission-denied',
        'unauthenticated',
        'not-found',
        'invalid-argument',
        'failed-precondition',
      ]) {
        expect(isTransportFailure(firebase(code)), isFalse, reason: code);
      }
    });

    test('falls back to the message when the code is not one it knows', () {
      // A lost connection reaches Dart through several unrelated doors, and the
      // codes only cover the one that stayed a FirebaseException.
      for (final message in [
        'The socket connection was closed',
        'Network error',
        'request timed out',
        'Connection reset by peer',
      ]) {
        expect(isTransportFailure(Exception(message)), isTrue, reason: message);
      }
    });

    test(
      'is case-insensitive, because these arrive capitalised from some layers',
      () {
        expect(isTransportFailure(Exception('TIMEOUT')), isTrue);
        expect(isTransportFailure(Exception('Network Error')), isTrue);
      },
    );

    test('an unrelated error is not a lost connection', () {
      expect(isTransportFailure(Exception('bad state')), isFalse);
      expect(isTransportFailure(StateError('permission')), isFalse);
    });
  });
}
