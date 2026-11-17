// The merge, without a store.
//
// `mergeMedicines` is the rule set [SyncedMedicineStore] both shows the user
// and writes into the cache, so these tests pin the rules where a regression
// cannot hide behind a stream.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/search/data/local/medicine_merge.dart';
import 'package:pharmaguide/features/search/data/models/age_guidance.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';

MedicineModel _line(
  String name, {
  String? productId,
  String? packageType,
  int price = 900,
  int? stock,
  DateTime? expiry,
  String? usage,
  String? genericKey,
  List<String> aliases = const [],
  AgeGuidance? guidance,
}) {
  return MedicineModel(
    name: name,
    productId: productId,
    packageType: packageType,
    priceCentavos: price,
    stock: stock,
    expiryDate: expiry,
    usageIndication: usage,
    genericKey: genericKey,
    aliases: aliases,
    ageGuidance: guidance,
  );
}

void main() {
  group('empty inputs', () {
    test('an empty server answers with the local rows', () {
      final base = [_line('Paracetamol', productId: '1')];
      expect(mergeMedicines(base: base, remote: const []), base);
    });

    test('an empty cache answers with the server', () {
      final remote = [_line('Paracetamol', productId: '1', stock: 5)];
      expect(mergeMedicines(base: const [], remote: remote), remote);
    });

    test('two empty inputs stay empty', () {
      expect(mergeMedicines(base: const [], remote: const []), isEmpty);
    });
  });

  group('matching by document id', () {
    test('the server line wins, and keeps the local description', () {
      final base = [
        _line('Alaxan FR', productId: '28', usage: 'For body aches'),
      ];
      final remote = [
        _line('Alaxan FR', productId: '28', stock: 7),
      ];

      final merged = mergeMedicines(base: base, remote: remote);

      expect(merged.single.stock, 7);
      expect(merged.single.usageIndication, 'For body aches');
    });

    test('a server line the cache does not know is added', () {
      final base = [_line('Paracetamol', productId: '1')];
      final added = _line('Biogesic', productId: '2', stock: 3);

      final merged = mergeMedicines(base: base, remote: [added]);

      expect(merged.map((m) => m.name), containsAll(['Paracetamol', 'Biogesic']));
    });

    test('a local line the server does not know is kept', () {
      final base = [
        _line('Biogesic', productId: '2', stock: 3),
        _line('Paracetamol', productId: '1'),
      ];

      final merged = mergeMedicines(
        base: base,
        remote: [_line('Paracetamol', productId: '1', stock: 9)],
      );

      final biogesic = merged.firstWhere((m) => m.name == 'Biogesic');
      expect(biogesic.stock, 3);
    });
  });

  group('pending writes', () {
    test('a pending edit is not overwritten by a stale snapshot', () {
      final base = [_line('Alaxan FR', productId: '28', stock: 12)];
      final remote = [
        _line('Alaxan FR', productId: '28', stock: 3),
      ];

      final merged = mergeMedicines(
        base: base,
        remote: remote,
        preferBaseIds: {base.single.documentId},
      );

      expect(merged.single.stock, 12);
    });

    test('a pending edit yields once the write is confirmed', () {
      final base = [_line('Alaxan FR', productId: '28', stock: 12)];
      final remote = [
        _line('Alaxan FR', productId: '28', stock: 12),
      ];

      final merged = mergeMedicines(base: base, remote: remote);

      expect(merged.single.stock, 12);
    });

    test('a pending edit on a legacy-matched line is also protected', () {
      final base = [_line('Amox', price: 400, stock: 6)];
      final remote = [_line('Amox', price: 400, stock: 2)];

      final merged = mergeMedicines(
        base: base,
        remote: remote,
        preferBaseIds: {base.single.documentId},
      );

      expect(merged.single.stock, 6);
    });
  });

  group('legacy identity', () {
    test('a line without a product id matches by name and price', () {
      final base = [
        _line('Amox', productId: '10', price: 400, usage: 'For infections'),
      ];
      final remote = [
        _line('Amox', price: 400, stock: 5, aliases: ['amoxi']),
      ];

      final merged = mergeMedicines(base: base, remote: remote);

      expect(merged, hasLength(1));
      expect(merged.single.stock, 5);
      expect(merged.single.aliases, ['amoxi']);
      expect(merged.single.usageIndication, 'For infections');
    });

    test('the same name at a different price is a different line', () {
      final base = [_line('Amox', price: 400)];
      final remote = [_line('Amox', price: 4500, stock: 2)];

      final merged = mergeMedicines(base: base, remote: remote);

      expect(merged, hasLength(2));
    });

    test('generic keys cross over without merging the lines', () {
      final base = [
        _line('Dolfenal', productId: '9', genericKey: 'mefenamic acid'),
      ];
      final remote = [
        _line('Dolfenal', productId: '9', genericKey: 'mefenamic acid',
            stock: 4),
      ];

      final merged = mergeMedicines(base: base, remote: remote);

      expect(merged.single.genericKey, 'mefenamic acid');
      expect(merged.single.stock, 4);
    });

    test('an ambiguous legacy name is not guessed at', () {
      final base = [
        _line('Amox', productId: '10', price: 400),
        _line('Amox', productId: '11', price: 400, packageType: 'Box'),
      ];
      final remote = [_line('Amox', price: 400, stock: 2)];

      final merged = mergeMedicines(base: base, remote: remote);

      // The remote line cannot be told which local line it belongs to, so it
      // is added as its own line rather than stamped onto one at random.
      expect(merged, hasLength(3));
    });

    test('age guidance is never dropped by the merge', () {
      final guidance = const AgeGuidance(
        kids: AgeSuitability.no,
        teens: AgeSuitability.yes,
        adults: AgeSuitability.yes,
        seniors: AgeSuitability.caution,
      );
      final base = [
        _line('Alaxan FR', productId: '28', guidance: guidance),
      ];
      final remote = [
        _line('Alaxan FR', productId: '28', stock: 8),
      ];

      final merged = mergeMedicines(base: base, remote: remote);

      expect(merged.single.ageGuidance, guidance);
    });
  });

  group('ordering', () => _ordering());
}

void _ordering() {
  test('the price list is alphabetical, then cheapest first', () {
    final base = [
      _line('Paracetamol', productId: '1'),
      _line('Amox', price: 4500),
      _line('Amox', price: 400),
    ];
    final remote = [_line('Cetirizine', productId: '5', stock: 1)];

    final merged = mergeMedicines(base: base, remote: remote);

    expect(
      merged.map((m) => m.name),
      ['Amox', 'Amox', 'Cetirizine', 'Paracetamol'],
    );
    final amoxPrices = merged
        .where((m) => m.name == 'Amox')
        .map((m) => m.priceCentavos)
        .toList();
    expect(amoxPrices, [400, 4500]);
  });
}
