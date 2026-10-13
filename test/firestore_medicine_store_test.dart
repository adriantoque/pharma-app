import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:pharmaguide/core/connectivity/connection_source.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/data/repositories/firestore_medicine_store.dart';
import 'package:pharmaguide/features/search/data/sync/pending_write_queue.dart';
import 'package:pharmaguide/features/search/data/sync/transport_failure.dart';

/// The store's two subtle behaviours, driven against an in-memory Firestore.
///
/// What the fake can and cannot reach, so the gaps below are deliberate rather
/// than forgotten:
///
/// * `MockSnapshotMetadata.hasPendingWrites` is always `false`, and a snapshot
///   cannot be forced to report `isFromCache: true`. The two early returns in
///   `_noteSnapshot` that depend on those flags are therefore not exercised
///   here; what is exercised is the intersection they protect, on a clean
///   snapshot.
/// * The fake's query stream cannot be made to emit an error, so the
///   `watchAll` error path (`_noteError`) is not reachable either. The
///   classification it leans on, `isTransportFailure`, is pure and is covered
///   directly at the bottom of this file.
/// * `FakeFirebaseFirestore.enableNetwork()` is not implemented (it throws), so
///   [_RecordingFirestore] overrides it to record that it was called.
const _amox = MedicineModel(name: 'Amox', priceCentavos: 400, stock: null);
const _zinc = MedicineModel(name: 'Zinc', priceCentavos: 250, stock: null);
const _iron = MedicineModel(name: 'Iron', priceCentavos: 100, stock: null);

CollectionReference<Map<String, dynamic>> _items(FirebaseFirestore firestore) =>
    firestore.collection('pharmacy').doc('medicines').collection('items');

Future<void> _seed(FirebaseFirestore firestore, MedicineModel medicine) =>
    _items(firestore).doc(medicine.documentId).set(medicine.toFirestore());

/// Lets pending platform and microtask work run.
Future<void> _settle() => pumpEventQueue();

/// Waits for [ready], failing rather than hanging if it never becomes true.
Future<void> _waitUntil(
  bool Function() ready, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition still false after $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// A [ConnectionSource] a test drives by hand.
class _FakeConnection implements ConnectionSource {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool? _connected;

  @override
  bool? get isConnected => _connected;

  @override
  Stream<bool> watch() => _controller.stream;

  void emit(bool connected) {
    _connected = connected;
    _controller.add(connected);
  }

  Future<void> close() => _controller.close();
}

/// A fake Firestore whose [enableNetwork] is real enough to observe.
///
/// Reads [onEnableNetwork] at the moment the network comes back, which is when
/// the store's replay has either already happened or not.
class _RecordingFirestore extends FakeFirebaseFirestore {
  _RecordingFirestore({this.onEnableNetwork});

  final Future<void> Function()? onEnableNetwork;

  int enableNetworkCalls = 0;

  @override
  Future<void> enableNetwork() async {
    enableNetworkCalls++;
    await onEnableNetwork?.call();
  }
}

void main() {
  // `whenCalling` keeps its registrations in a process-wide map keyed by the
  // document reference, and a reference's key includes its Firestore instance.
  // Each test builds its own fake, so a registration in one test cannot match a
  // call in another and no teardown is needed to keep them apart.
  group('FirestoreMedicineStore', () {
    test('reads the catalogue and sorts it the way the app does', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore, _zinc);
      await _seed(firestore, _amox);

      final store = FirestoreMedicineStore(
        firestore: firestore,
        queue: InMemoryPendingWriteQueue(),
      );
      addTearDown(store.dispose);

      final medicines = await store.watchAll().first;

      expect(medicines.map((medicine) => medicine.name), ['Amox', 'Zinc']);
    });

    test(
      'a clean snapshot confirms the writes on the wire and leaves the others',
      () async {
        final firestore = FakeFirebaseFirestore();
        await _seed(firestore, _amox);
        await _seed(firestore, _zinc);
        await _seed(firestore, _iron);

        final queue = InMemoryPendingWriteQueue();
        final store = FirestoreMedicineStore(
          firestore: firestore,
          queue: queue,
        );
        addTearDown(store.dispose);
        final subscription = store.watchAll().listen((_) {});
        addTearDown(subscription.cancel);
        await _settle();

        // A write that was recorded but never got to the wire -- what a crash
        // between the record and the send leaves behind. It is the exact case
        // the queue exists for, so a clean snapshot must not confirm it.
        final stranded = await queue.add(
          documentId: _zinc.documentId,
          fields: {'stock': 3},
        );

        // A write this store actually sends.
        await store.setStock(_amox, 7);

        // A fresh snapshot, so confirmation is evaluated after the sent write
        // was put on the wire rather than racing the acknowledgement.
        await _items(firestore).doc(_iron.documentId).update({'stock': 12});
        await _waitUntil(
          () => !queue.pending.any(
            (write) => write.documentId == _amox.documentId,
          ),
        );

        expect(queue.pending.map((write) => write.id), contains(stranded.id));
        expect(
          (await _items(
            firestore,
          ).doc(_amox.documentId).get()).data()!['stock'],
          7,
        );
        expect(
          (await _items(
            firestore,
          ).doc(_zinc.documentId).get()).data()!['stock'],
          isNull,
          reason: 'the stranded write was never applied, so it must not show',
        );
      },
    );

    test('reconnect replays queued writes before enabling the network', () async {
      Map<String, dynamic>? documentWhenEnabled;
      late _RecordingFirestore firestore;
      firestore = _RecordingFirestore(
        onEnableNetwork: () async {
          documentWhenEnabled = (await _items(
            firestore,
          ).doc(_amox.documentId).get()).data();
        },
      );
      await _seed(firestore, _amox);

      final connection = _FakeConnection();
      addTearDown(connection.close);
      final queue = InMemoryPendingWriteQueue();
      final store = FirestoreMedicineStore(
        firestore: firestore,
        queue: queue,
        connection: connection,
      );
      addTearDown(store.dispose);
      await _settle();

      // A write left over from a previous run: queued, never sent.
      await queue.add(documentId: _amox.documentId, fields: {'stock': 9});
      expect(firestore.enableNetworkCalls, 0);

      connection.emit(true);
      await _waitUntil(() => firestore.enableNetworkCalls == 1);

      expect(
        documentWhenEnabled?['stock'],
        9,
        reason:
            'the replayed write has to be sent before enableNetwork, or the '
            'clean snapshot that follows could confirm a write that never left',
      );
    });

    test('a refused write is rethrown and dropped from the queue', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore, _amox);

      whenCalling(Invocation.method(#set, []))
          .on(_items(firestore).doc(_amox.documentId))
          .thenThrow(
            FirebaseException(
              plugin: 'test',
              code: 'permission-denied',
              message: 'denied',
            ),
          );

      final queue = InMemoryPendingWriteQueue();
      final store = FirestoreMedicineStore(firestore: firestore, queue: queue);
      addTearDown(store.dispose);

      await expectLater(
        store.setStock(_amox, 9),
        throwsA(isA<FirebaseException>()),
      );
      expect(queue.pending, isEmpty);
    });

    test('a transport failure leaves the write queued and tells the caller nothing', () async {
      final firestore = FakeFirebaseFirestore();
      await _seed(firestore, _amox);

      whenCalling(Invocation.method(#set, []))
          .on(_items(firestore).doc(_amox.documentId))
          .thenThrow(FirebaseException(plugin: 'test', code: 'unavailable'));

      final queue = InMemoryPendingWriteQueue();
      final store = FirestoreMedicineStore(firestore: firestore, queue: queue);
      addTearDown(store.dispose);

      await store.setStock(_amox, 9);

      expect(queue.pending, hasLength(1));
      expect(queue.pending.single.documentId, _amox.documentId);
    });
  });

  group('isTransportFailure', () {
    test('reads Firestore\'s own transport codes as retryable', () {
      for (final code in [
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
      ]) {
        expect(
          isTransportFailure(FirebaseException(plugin: 'test', code: code)),
          isTrue,
          reason: code,
        );
      }
    });

    test('reads a refusal as not retryable', () {
      for (final code in [
        'permission-denied',
        'not-found',
        'invalid-argument',
      ]) {
        expect(
          isTransportFailure(
            FirebaseException(plugin: 'test', code: code, message: 'no'),
          ),
          isFalse,
          reason: code,
        );
      }
    });

    test(
      'sniffs the transport strings out of errors that never became a code',
      () {
        expect(isTransportFailure(Exception('socket closed')), isTrue);
        expect(isTransportFailure(Exception('Network is unreachable')), isTrue);
        expect(isTransportFailure(TimeoutException('no answer')), isTrue);
        expect(isTransportFailure(Exception('something else')), isFalse);
      },
    );
  });
}
