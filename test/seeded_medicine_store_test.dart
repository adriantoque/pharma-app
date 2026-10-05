import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/data/repositories/bundled_medicine_source.dart';
import 'package:pharmaguide/features/search/data/repositories/seeded_medicine_store.dart';
import 'package:pharmaguide/features/search/data/sync/sync_status.dart';
import 'package:pharmaguide/features/search/data/sync/sync_status_source.dart';

import 'helpers/fake_medicine_store.dart';

void main() {
  /// The id is derived from the name and price rather than settable, so a fixture
  /// is named by its name and the merge's identity comes out of the model itself.
  MedicineModel medicine(String name, {int? stock}) =>
      MedicineModel(name: name, priceCentavos: 100, stock: stock);

  /// Waits for the stream's last list, once [count] of them have arrived.
  ///
  /// Not `stream.first`: the bundled list is emitted as soon as it is read, which
  /// is the whole point of the store, so the first list is often not the one a
  /// merge test wants to look at. Taking the last of a fixed count says which one
  /// is meant without leaning on event ordering that the store does not promise.
  Future<List<MedicineModel>> settle(
    Stream<List<MedicineModel>> stream, {
    int count = 2,
  }) async {
    final seen = await stream.take(count).toList();
    return seen.last;
  }

  group('bundled list is shown when the server is unreachable', () {
    test('the list survives a failed read', () async {
      final remote = FakeMedicineStore()..failReads(StateError('offline'));
      final store = SeededMedicineStore(
        remote: remote,
        bundled: ListMedicineSource([medicine('A'), medicine('B')]),
      );

      expect(await store.watchAll().first, [medicine('A'), medicine('B')]);
    });

    test('a failure with nothing to fall back on is passed on', () async {
      final failure = StateError('no bundle either');
      final remote = FakeMedicineStore()..failReads(failure);
      // An empty bundle stands in for an unreadable asset: the store must not
      // swallow the failure and hand back an empty price list as if it were real.
      final store = SeededMedicineStore(
        remote: remote,
        bundled: ListMedicineSource(const []),
      );

      await expectLater(
        store.watchAll().first,
        throwsA(same(failure)),
        reason: 'the caller is told the read failed rather than handed an empty '
            'price list that reads as a real one',
      );
    });
  });

  group('bundled and server lists are merged', () {
    test('the server wins on a line both have', () async {
      // Same name and price on both sides, which is what makes them the same document:
      // the id is derived from those two, not assigned.
      final remote = FakeMedicineStore(initial: [medicine('Amox', stock: 5)]);
      final store = SeededMedicineStore(
        remote: remote,
        bundled: ListMedicineSource([medicine('Amox'), medicine('Benz')]),
      );

      final merged = await settle(store.watchAll());

      expect(
        merged.map((item) => item.name),
        ['Amox', 'Benz'],
        reason: 'the server copy replaces the bundled one rather than doubling it',
      );
      expect(
        merged.first.stock,
        5,
        reason: 'the count the counter typed must survive the merge',
      );
    });

    test('the list stays sorted', () async {
      final store = SeededMedicineStore(
        remote: FakeMedicineStore(initial: [medicine('Zed')]),
        bundled: ListMedicineSource([
          medicine('Alpha'),
          medicine('Beta'),
        ]),
      );

      expect(
        (await settle(store.watchAll())).map((item) => item.name),
        ['Alpha', 'Beta', 'Zed'],
      );
    });

    test('an empty server list leaves the bundled list alone', () async {
      final store = SeededMedicineStore(
        remote: FakeMedicineStore(),
        bundled: ListMedicineSource([medicine('A'), medicine('B')]),
      );

      expect(await store.watchAll().first, hasLength(2));
    });
  });

  group('seeding a new account', () {
    test('an empty account is filled from the bundle', () async {
      final remote = FakeMedicineStore();
      final store = SeededMedicineStore(
        remote: remote,
        bundled: ListMedicineSource([medicine('A'), medicine('B')]),
      );

      await store.watchAll().first;
      // The upload is queued behind the first snapshot, so the list is awaited
      // once more to let it land.
      await pumpEventQueue();

      expect(remote.operations, ['upsertAll 2']);
    });

    test('an account that already has lines is left alone', () async {
      final remote = FakeMedicineStore(initial: [medicine('A', stock: 3)]);
      final store = SeededMedicineStore(
        remote: remote,
        bundled: ListMedicineSource([medicine('A'), medicine('B')]),
      );

      await store.watchAll().first;
      await pumpEventQueue();

      expect(
        remote.operations,
        isEmpty,
        reason: 'putting deleted lines back on every launch would undo the '
            'pharmacist\'s own decision',
      );
    });

    test('seeding happens once, not on every snapshot', () async {
      final remote = FakeMedicineStore();
      final store = SeededMedicineStore(
        remote: remote,
        bundled: ListMedicineSource([medicine('A')]),
      );

      final subscription = store.watchAll().listen((_) {});
      await pumpEventQueue();
      remote.emit([]);
      await pumpEventQueue();

      await subscription.cancel();
      expect(remote.operations, ['upsertAll 1']);
    });

    test('a failed upload does not stop the list being shown', () async {
      final remote = FakeMedicineStore()..writeError = StateError('refused');
      final store = SeededMedicineStore(
        remote: remote,
        bundled: ListMedicineSource([medicine('A')]),
      );

      expect(await store.watchAll().first, [medicine('A')]);
    });
  });

  group('writes', () {
    test('go straight to the inner store', () async {
      final remote = FakeMedicineStore(initial: [medicine('A')]);
      final store = SeededMedicineStore(
        remote: remote,
        bundled: ListMedicineSource([medicine('A')]),
      );

      await store.setStock(medicine('A'), 4);
      await store.setExpiry(medicine('A'), DateTime(2027, 3, 1));

      expect(remote.operations, [
        'setStock A -> 4',
        'setExpiry A -> 2027-03-01 00:00:00.000',
      ]);
    });
  });

  group('sync status', () {
    test('is passed through from a store that reports one', () async {
      final remote = FakeSyncingMedicineStore(
        status: offlineStatus,
      );
      final store = SeededMedicineStore(
        remote: remote,
        bundled: ListMedicineSource([medicine('A')]),
      );

      expect(await store.watchSyncStatus().first,
          offlineStatus);
    });

    test('reads as local-only when the inner store cannot report', () async {
      final store = SeededMedicineStore(
        remote: FakeMedicineStore(),
        bundled: ListMedicineSource([medicine('A')]),
      );

      expect(
        (await store.watchSyncStatus().first).reachability,
        Reachability.online,
        reason: 'a store with no server behind it cannot be offline',
      );
    });

    test('a live update from the inner store arrives unchanged', () async {
      final remote = FakeSyncingMedicineStore();
      final store = SeededMedicineStore(
        remote: remote,
        bundled: ListMedicineSource([medicine('A')]),
      );

      final List<SyncStatus> seen = [];
      final subscription = store.watchSyncStatus().listen(seen.add);
      await pumpEventQueue();
      remote.report(offlineStatus);
      await pumpEventQueue();

      await subscription.cancel();
      expect(seen.last, offlineStatus);
    });
  });

  group('disposal', () {
    test('releases an inner store that asks to be released', () {
      final remote = _ReleasableStore();
      SeededMedicineStore(
        remote: remote,
        bundled: ListMedicineSource([medicine('A')]),
      ).dispose();

      expect(remote.disposed, isTrue);
    });

    test('can be called twice', () {
      final store = SeededMedicineStore(
        remote: FakeMedicineStore(),
        bundled: ListMedicineSource([medicine('A')]),
      );

      store.dispose();
      expect(store.dispose, returnsNormally);
    });

    test('a store that does not opt in is left alone', () {
      // FakeMedicineStore has a dispose method but does not declare
      // DisposableStore, which is the point: the store must not reach for it by
      // duck typing and release something its owner still holds.
      final remote = FakeMedicineStore();
      SeededMedicineStore(
        remote: remote,
        bundled: ListMedicineSource([medicine('A')]),
      ).dispose();

      expect(remote.disposed, isFalse);
    });
  });

  group('two watchers', () {
    test('each gets its own stream', () async {
      final remote = FakeMedicineStore(initial: [medicine('A')]);
      final store = SeededMedicineStore(
        remote: remote,
        bundled: ListMedicineSource([medicine('A'), medicine('B')]),
      );

      final first = store.watchAll().first;
      final second = store.watchAll().first;

      expect(await first, hasLength(2));
      expect(await second, hasLength(2));
    });
  });
}

/// A store that has opted into being released.
class _ReleasableStore extends FakeMedicineStore implements DisposableStore {}

/// Named so a test can say what it means instead of spelling out a reachability\n// it does not care about.
const offlineStatus = SyncStatus(reachability: Reachability.offline);