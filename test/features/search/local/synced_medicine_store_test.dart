// [SyncedMedicineStore], driven by hand.
//
// The remote is a fake the test emits into, and the cache is a fake the test
// can read and refuse writes on, so the ordering rules -- base before server,
// mirror after merge, writes that never leave the device, shelf edits that
// survive a stale snapshot -- are staged rather than raced.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/search/data/local/synced_medicine_store.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/data/repositories/bundled_medicine_source.dart';
import 'package:pharmaguide/features/search/data/sync/sync_status.dart';

import 'fakes.dart';

MedicineModel _line(
  String name, {
  String? productId,
  int price = 900,
  int? stock,
  String? usage,
}) {
  return MedicineModel(
    name: name,
    productId: productId,
    priceCentavos: price,
    stock: stock,
    usageIndication: usage,
  );
}

/// The number of event-loop turns a pump chain needs to settle.
///
/// Every await inside the store is a microtask or a fake's immediate future,
/// so a macrotask turn per hop is generous. Twelve covers the longest chain a
/// single event can start.
const int _turns = 12;

void main() {
  late FakeMedicineCache cache;
  late FakeRemoteMedicineStore remote;

  setUp(() {
    cache = FakeMedicineCache();
    remote = FakeRemoteMedicineStore();
  });

  SyncedMedicineStore buildStore({
    List<MedicineModel> bundle = const [],
  }) {
    return SyncedMedicineStore(
      local: cache,
      remote: remote,
      bundled: ListMedicineSource(bundle),
    );
  }

  group('reading', () {
    test('shows the cached rows before the server has answered', () async {
      final alaxan = _line('Alaxan FR', productId: '28', stock: 9);
      cache.seedAll([alaxan]);

      final (events, _) = await buildStore().watchAll().record(_turns);

      expect(events, isNotEmpty);
      expect(events.first, [alaxan]);
    });

    test('lays the server answer over the cache', () async {
      final alaxan = _line('Alaxan FR', productId: '28', usage: 'For pain');
      final serverCopy = _line('Alaxan FR', productId: '28', stock: 7);
      cache.seedAll([alaxan]);

      final store = buildStore();
      final recorded = store.watchAll().record(_turns);
      remote.emit([serverCopy]);
      final (events, _) = await recorded;

      final shown = events.last;
      expect(shown, hasLength(1));
      expect(shown.single.stock, 7);
      // The description only the cache had is not blanked out by the server's
      // older copy of the same line.
      expect(shown.single.usageIndication, 'For pain');
    });

    test('mirrors the merged view into the cache', () async {
      final alaxan = _line('Alaxan FR', productId: '28', usage: 'For pain');
      cache.seedAll([alaxan]);
      final serverCopy = _line('Alaxan FR', productId: '28', stock: 7);

      final store = buildStore();
      final recorded = store.watchAll().record(_turns);
      remote.emit([serverCopy]);
      await recorded;

      final stored = await cache.loadAll();
      expect(stored.single.stock, 7);
      expect(stored.single.usageIndication, 'For pain');
    });

    test('mirrors a server line the cache has never seen', () async {
      final store = buildStore();
      final recorded = store.watchAll().record(_turns);
      remote.emit([
        _line('Biogesic', productId: '2', stock: 3),
      ]);
      await recorded;

      expect(await cache.findById(_line('Biogesic', productId: '2').documentId),
          isNotNull);
    });

    test('a mirror that changes nothing emits nothing new', () async {
      final alaxan = _line('Alaxan FR', productId: '28', stock: 9);
      cache.seedAll([alaxan]);

      final store = buildStore();
      final recorded = store.watchAll().record(_turns);
      // The same row, twice: the first snapshot already matched what the cache
      // had shown, and the second changes nothing on top of it.
      remote.emit([alaxan]);
      remote.emit([alaxan]);
      final (events, _) = await recorded;

      // One emission from the base read, and none from either snapshot.
      expect(events, hasLength(1));
    });

    test('an empty cache and an erroring server report the error', () async {
      final recorded = buildStore().watchAll().record(_turns);
      remote.emitError(StateError('Could not reach Firestore'));
      final (events, errors) = await recorded;

      // With nothing cached and nothing served, the failure is worth
      // reporting rather than dressed up as an empty price list.
      expect(events, isEmpty);
      expect(errors, isNotEmpty);
    });
  });

  group('shelf edits against snapshots', () {
    test('a stale snapshot cannot undo a shelf edit', () async {
      final alaxan = _line('Alaxan FR', productId: '28');
      cache.seedAll([alaxan]);

      final store = buildStore();
      final recorded = store.watchAll().record(_turns);

      await store.setStock(alaxan, 12);
      // No pending ids, no queue: medicine writes never reach the server, so
      // the protection is the merge's own -- the shelf fields are local facts.
      remote.emit([_line('Alaxan FR', productId: '28', stock: 3)]);
      final (events, _) = await recorded;

      final shown = events.last;
      expect(shown.single.stock, 12);
      // The cache kept it too, which is what a restart would read.
      expect((await cache.loadAll()).single.stock, 12);
    });

    test('a snapshot fills an uncounted line the edit has not touched',
        () async {
      final alaxan = _line('Alaxan FR', productId: '28');
      cache.seedAll([alaxan]);

      final store = buildStore();
      final recorded = store.watchAll().record(_turns);

      // A local line with no count yet takes the server's, so a fresh device
      // still inherits the counts the catalogue carried.
      remote.emit([_line('Alaxan FR', productId: '28', stock: 3)]);
      final (events, _) = await recorded;

      expect(events.last.single.stock, 3);
    });

    test('an expiry edit survives a snapshot that does not carry it', () async {
      final alaxan = _line(
        'Alaxan FR',
        productId: '28',
      ).copyWith(expiryDate: DateTime(2026, 1, 15));
      cache.seedAll([alaxan]);

      final store = buildStore();
      final recorded = store.watchAll().record(_turns);

      await store.setExpiry(alaxan, DateTime(2027, 6, 1));
      remote.emit([
        _line('Alaxan FR', productId: '28').copyWith(
          expiryDate: DateTime(2026, 1, 15),
        ),
      ]);
      final (events, _) = await recorded;

      expect(events.last.single.expiryDate, DateTime(2027, 6, 1));
    });
  });

  group('writing', () {
    test('a stock count goes to the cache and not the server', () async {
      final alaxan = _line('Alaxan FR', productId: '28');
      cache.seedAll([alaxan]);

      await buildStore().setStock(alaxan, 5);

      expect(cache.operations, contains('setStock/${alaxan.documentId}/5'));
      expect(remote.operations, isEmpty);
      expect((await cache.findById(alaxan.documentId))!.stock, 5);
    });

    test('an expiry goes to the cache and not the server', () async {
      final alaxan = _line('Alaxan FR', productId: '28');
      cache.seedAll([alaxan]);

      await buildStore().setExpiry(alaxan, DateTime(2027, 6, 1));

      expect(cache.operations, contains('setExpiry/${alaxan.documentId}'));
      expect(remote.operations, isEmpty);
      expect(
        (await cache.findById(alaxan.documentId))!.expiryDate,
        DateTime(2027, 6, 1),
      );
    });

    test('an upsert goes to the cache and not the server', () async {
      final biogesic = _line('Biogesic', productId: '2');

      await buildStore().upsert(biogesic);

      expect(cache.operations, contains('upsert/${biogesic.documentId}'));
      expect(remote.operations, isEmpty);
      expect(cache.contains(biogesic.documentId), isTrue);
    });

    test('an import goes to the cache and not the server', () async {
      final import = [_line('Biogesic', productId: '2', stock: 8)];

      await buildStore().upsertAll(import);

      expect(cache.operations, contains('upsertAll/1'));
      expect(remote.operations, isEmpty);
      expect(
        (await cache.findById(_line('Biogesic', productId: '2').documentId))!
            .stock,
        8,
      );
    });

    test('a server refusal cannot touch a medicine write', () async {
      // The failure this file exists to pin: PERMISSION_DENIED used to arrive
      // after the local write and roll the edit back out from under the
      // pharmacist. Writes no longer reach the server, so a refusal armed on
      // it must never fire and the edit must stand.
      final alaxan = _line('Alaxan FR', productId: '28', stock: 9);
      cache.seedAll([alaxan]);
      final store = buildStore();
      remote.writeError = StateError('PERMISSION_DENIED');

      await store.setStock(alaxan, 12);
      await store.setExpiry(alaxan, DateTime(2027, 6, 1));
      await store.upsert(_line('Biogesic', productId: '2'));

      expect(remote.operations, isEmpty);
      expect((await cache.findById(alaxan.documentId))!.stock, 12);
      expect(
        (await cache.findById(alaxan.documentId))!.expiryDate,
        DateTime(2027, 6, 1),
      );
    });

    test('a failing cache write still propagates', () async {
      // The provider paints optimistically and rolls back on a thrown error,
      // so a cache that cannot write must be heard -- nothing is swallowed.
      final alaxan = _line('Alaxan FR', productId: '28');
      cache.seedAll([alaxan]);
      final store = buildStore();
      cache.refuseWrites = true;

      await expectLater(store.setStock(alaxan, 12), throwsStateError);

      expect(remote.operations, isEmpty);
    });
  });

  group('seeding the server', () {
    test('uploads the bundle when the server is empty', () async {
      final bundle = [_line('Paracetamol', productId: '1')];

      final store = buildStore(bundle: bundle);
      final recorded = store.watchAll().record(_turns);
      remote.emit(const []);
      await recorded;

      expect(remote.operations, contains('upsertAll/1'));
      expect(remote.stored, containsPair(_line('Paracetamol', productId: '1').documentId, anything));
    });

    test('does not upload when the server already has the bundle', () async {
      final bundle = [_line('Paracetamol', productId: '1')];

      final store = buildStore(bundle: bundle);
      final recorded = store.watchAll().record(_turns);
      remote.emit(bundle);
      await recorded;

      expect(remote.operations.where((op) => op.startsWith('upsertAll')),
          isEmpty);
    });

    test('leaves a legacy collection alone', () async {
      final bundle = [_line('Paracetamol', productId: '1')];

      final store = buildStore(bundle: bundle);
      final recorded = store.watchAll().record(_turns);
      // Every line without a product id: a collection seeded by an older build.
      remote.emit([_line('Amox', price: 400)]);
      await recorded;

      expect(remote.operations.where((op) => op.startsWith('upsertAll')),
          isEmpty);
    });
  });

  group('lifecycle', () {
    test('dispose tolerates a second call and the cache outlives it', () {
      final store = buildStore();
      store.dispose();
      store.dispose();
      // The cache is app-scoped: disposing the store must not have touched it.
      expect(cache.loadCount, isZero);
    });

    test('the sync status is the remote store\'s', () async {
      final status = await buildStore().watchSyncStatus().first;
      expect(status.reachability, Reachability.online);
    });
  });
}

