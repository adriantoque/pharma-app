// [DriftMedicineStore] against a real SQLite database.
//
// These tests need a SQLite library the test runner does not ship. When one is
// available (see `test/helpers/sqlite3_for_tests.dart`) they run against an
// in-memory database; when it is not, they skip rather than fail, because the
// store logic itself is covered database-free by the codec, merge and synced
// store suites.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/search/data/local/app_database.dart';
import 'package:pharmaguide/features/search/data/local/drift_medicine_store.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';
import 'package:pharmaguide/features/search/data/repositories/bundled_medicine_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/sqlite3_for_tests.dart';

MedicineModel _line(
  String name, {
  String? productId,
  int price = 900,
  int? stock,
  DateTime? expiry,
  String? usage,
}) {
  return MedicineModel(
    name: name,
    productId: productId,
    priceCentavos: price,
    stock: stock,
    expiryDate: expiry,
    usageIndication: usage,
  );
}

/// The legacy id the previous build keyed its overlay patches by.
String _legacyId(MedicineModel medicine) {
  // The hash input the previous build used for lines without a product id.
  var hash = 0x811c9dc5;
  for (final unit in '${medicine.name}|${medicine.priceCentavos}'.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

Future<void> main() async {
  // Resolved before anything registers, so a missing library reads as `skip`
  // rather than as a failure inside every test.
  final sqlite = await sqlite3Available;

  late AppDatabase database;

  setUp(() {
    if (!sqlite) return;
    database = openInMemoryAppDatabase();
  });

  tearDown(() async {
    if (!sqlite) return;
    await database.close();
  });

  Future<DriftMedicineStore> buildStore({
    List<MedicineModel> bundle = const [],
    Map<String, String> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    return DriftMedicineStore(
      database: database,
      bundled: ListMedicineSource(bundle),
      prefs: Future.value(SharedPreferences.getInstance()),
    );
  }

  group('seeding', () {
    test(
      'fills an empty database from the bundle',
      skip: sqlite ? false : 'sqlite3 library not available',
      () async {
        final store = await buildStore(
          bundle: [_line('Paracetamol', productId: '1')],
        );

        final loaded = await store.loadAll();

        expect(loaded, hasLength(1));
        expect(loaded.single.name, 'Paracetamol');
        // The bundle is a price list, not an inventory: nobody has counted it.
        expect(loaded.single.stock, isNull);
      },
    );

    test(
      'seeds only once -- a refill does not overwrite stored counts',
      skip: sqlite ? false : 'sqlite3 library not available',
      () async {
        final paracetamol = _line('Paracetamol', productId: '1');
        final store = await buildStore(bundle: [paracetamol]);
        await store.setStock(paracetamol, 7);

        // A second store over the same database re-runs the seed check, finds
        // rows, and must leave the count alone.
        final second = await buildStore(bundle: [paracetamol]);
        final loaded = await second.loadAll();

        expect(loaded.single.stock, 7);
      },
    );
  });

  group('overlay migration', () {
    test(
      "carries the previous build's offline edits across",
      skip: sqlite ? false : 'sqlite3 library not available',
      () async {
        final paracetamol = _line('Paracetamol', productId: '1');
        final overlay = {
          // Keyed the way the previous build keyed it: the legacy hash, plus a
          // patch holding only the fields somebody typed.
          _legacyId(paracetamol): {
            'stock': 12,
            'expiryDate': '2027-06-01',
          },
        };

        final store = await buildStore(
          bundle: [paracetamol],
          prefs: {'offlineMedicinesOverlay': jsonEncode(overlay)},
        );
        final loaded = await store.loadAll();

        expect(loaded.single.stock, 12);
        expect(loaded.single.expiryDate, DateTime(2027, 6, 1));
      },
    );

    test(
      'deletes the overlay key once it has been applied',
      skip: sqlite ? false : 'sqlite3 library not available',
      () async {
        final paracetamol = _line('Paracetamol', productId: '1');
        SharedPreferences.setMockInitialValues({
          'offlineMedicinesOverlay': jsonEncode({
            _legacyId(paracetamol): {'stock': 12},
          }),
        });
        final store = DriftMedicineStore(
          database: database,
          bundled: ListMedicineSource([paracetamol]),
          prefs: Future.value(SharedPreferences.getInstance()),
        );
        await store.loadAll();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('offlineMedicinesOverlay'), isNull);
      },
    );

    test(
      'ignores an overlay id no row answers to',
      skip: sqlite ? false : 'sqlite3 library not available',
      () async {
        final store = await buildStore(
          bundle: [_line('Paracetamol', productId: '1')],
          prefs: {
            'offlineMedicinesOverlay': jsonEncode({
              'beefcafe': {'stock': 99},
            }),
          },
        );

        final loaded = await store.loadAll();
        expect(loaded.single.stock, isNull);
      },
    );

    test(
      'survives an overlay that does not decode',
      skip: sqlite ? false : 'sqlite3 library not available',
      () async {
        final store = await buildStore(
          bundle: [_line('Paracetamol', productId: '1')],
          prefs: {'offlineMedicinesOverlay': 'not json at all'},
        );

        final loaded = await store.loadAll();
        expect(loaded, hasLength(1));
      },
    );
  });

  group('writes', () {
    test(
      'setStock writes only the count',
      skip: sqlite ? false : 'sqlite3 library not available',
      () async {
        final alaxan = _line(
          'Alaxan FR',
          productId: '28',
          expiry: DateTime(2027, 3, 9),
          usage: 'For body aches',
        );
        final store = await buildStore(bundle: [alaxan]);

        await store.setStock(alaxan, 4);

        final loaded = await store.loadAll();
        expect(loaded.single.stock, 4);
        expect(loaded.single.expiryDate, alaxan.expiryDate);
        expect(loaded.single.usageIndication, 'For body aches');
      },
    );

    test(
      'clearing a count writes null, not zero',
      skip: sqlite ? false : 'sqlite3 library not available',
      () async {
        final alaxan = _line('Alaxan FR', productId: '28');
        final store = await buildStore(bundle: [alaxan]);
        await store.setStock(alaxan, 4);

        await store.setStock(alaxan, null);

        final loaded = await store.loadAll();
        expect(loaded.single.stock, isNull);
        expect(loaded.single.stockState, StockState.unknown);
      },
    );

    test(
      'upsert replaces the row in place',
      skip: sqlite ? false : 'sqlite3 library not available',
      () async {
        final store = await buildStore(bundle: [_line('Amox', price: 400)]);
        final repackaged = _line('Amox', price: 400, stock: 10);

        await store.upsert(repackaged);

        final loaded = await store.loadAll();
        expect(loaded, hasLength(1));
        expect(loaded.single.stock, 10);
      },
    );

    test(
      'upsertAll writes a whole import',
      skip: sqlite ? false : 'sqlite3 library not available',
      () async {
        final store = await buildStore(bundle: [_line('Amox', price: 400)]);

        await store.upsertAll([
          _line('Amox', price: 400, stock: 3),
          _line('Biogesic', productId: '2', stock: 8),
        ]);

        final loaded = await store.loadAll();
        expect(loaded.map((m) => m.name), unorderedEquals(['Amox', 'Biogesic']));
      },
    );

    test(
      'setExpiry records the date the pharmacist wrote',
      skip: sqlite ? false : 'sqlite3 library not available',
      () async {
        final alaxan = _line('Alaxan FR', productId: '28');
        final store = await buildStore(bundle: [alaxan]);

        await store.setExpiry(alaxan, DateTime(2027, 3, 9));

        final loaded = await store.loadAll();
        expect(loaded.single.expiryDate, DateTime(2027, 3, 9));
      },
    );
  });

  group('watching', () {
    test(
      'watchAll shows seeded rows and then the edits',
      skip: sqlite ? false : 'sqlite3 library not available',
      () async {
        final alaxan = _line('Alaxan FR', productId: '28');
        final store = await buildStore(bundle: [alaxan]);

        final events = <List<MedicineModel>>[];
        final subscription = store.watchAll().listen(events.add);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(events, isNotEmpty);
        expect(events.first.single.name, 'Alaxan FR');

        await store.setStock(alaxan, 15);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(events.last.single.stock, 15);
      },
    );
  });

  group('identity', () {
    test(
      'rows are keyed by document id, so a re-import updates in place',
      skip: sqlite ? false : 'sqlite3 library not available',
      () async {
        final paracetamol = _line('Paracetamol', productId: '1');
        final store = await buildStore(bundle: [paracetamol]);
        await store.setStock(paracetamol, 5);

        final row = await database.findMedicine(paracetamol.documentId);

        expect(row, isNotNull);
        expect(row!.id, paracetamol.documentId);
      },
    );
  });
}
