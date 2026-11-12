import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/admin/data/models/store_settings_model.dart';
import 'package:pharmaguide/features/admin/data/repositories/store_settings_repository.dart';

void main() {
  group('FirestoreStoreSettingsRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreStoreSettingsRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = FirestoreStoreSettingsRepository(firestore: firestore);
    });

    test('a fresh install has no document, and watch says so with a null', () async {
      expect(await repository.watch().first, isNull);
    });

    test('the first save creates the document, and watch hands it back', () async {
      const settings = StoreSettingsModel(
        name: 'Rosedale Pharmacy',
        lowStockThreshold: 8,
        expiryWarningDays: 60,
      );

      await repository.save(settings);

      // The document landed at the fixed singleton path the security rule
      // protects, not at an auto id the rule cannot reach.
      final document = await firestore
          .collection('settings')
          .doc('store')
          .get();
      expect(document.exists, isTrue);

      final watched = await repository.watch().first;
      expect(watched, settings);
    });

    test('a second save replaces the values rather than adding a document', () async {
      await repository.save(const StoreSettingsModel(name: 'First'));
      await repository.save(const StoreSettingsModel(name: 'Second'));

      expect(await repository.watch().first, const StoreSettingsModel(name: 'Second'));

      final count = await firestore.collection('settings').get();
      expect(count.docs, hasLength(1));
    });

    test('a listener sees a save made after it subscribed', () async {
      final updates = <StoreSettingsModel?>[];
      final subscription = repository.watch().listen(updates.add);

      await Future<void>.delayed(Duration.zero);
      await repository.save(const StoreSettingsModel(name: 'Live'));

      await Future<void>.delayed(Duration.zero);
      expect(updates.last, const StoreSettingsModel(name: 'Live'));

      await subscription.cancel();
    });
  });

  group('InMemoryStoreSettingsRepository', () {
    test('behaves like the Firestore one: null, then the saved value', () async {
      final repository = InMemoryStoreSettingsRepository();

      expect(await repository.watch().first, isNull);

      const settings = StoreSettingsModel(name: 'In memory');
      await repository.save(settings);

      expect(await repository.watch().first, settings);
      expect(repository.value, settings);
    });

    test('a save made right after subscribing is not dropped', () async {
      // Regression: a save that landed in the gap between a listener
      // subscribing and the feed attaching used to vanish -- the listener
      // then sat on a stale value until the next save. This is the exact
      // order the settings screen's tests hit.
      final repository = InMemoryStoreSettingsRepository();
      final updates = <StoreSettingsModel?>[];
      final subscription = repository.watch().listen(updates.add);

      await Future<void>.delayed(Duration.zero);
      await repository.save(const StoreSettingsModel(name: 'Not dropped'));

      await Future<void>.delayed(Duration.zero);
      expect(
        updates,
        contains(const StoreSettingsModel(name: 'Not dropped')),
      );

      await subscription.cancel();
    });
  });

  group('the saved document shape', () {
    test('carries the timestamp field the rules expect to ignore', () {
      // The repository stamps `updatedAt` server-side with a sentinel the
      // fake materialises as a timestamp; the model's map itself must not
      // carry a client clock for it, or the server stamp would be clobbered
      // by a value the writer's clock invented.
      final map = const StoreSettingsModel(name: 'A').toMap();
      expect(map.containsKey('updatedAt'), isFalse);
    });

    test('writes a server timestamp on save, which reads back as a date', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreStoreSettingsRepository(firestore: firestore);

      await repository.save(const StoreSettingsModel(name: 'Stamped'));

      final data = (await firestore.collection('settings').doc('store').get())
          .data()!;
      expect(data['updatedAt'], isA<Timestamp>());

      final settings = StoreSettingsModel.fromMap(data);
      expect(settings.updatedAt, isA<DateTime>());
      expect(settings.updatedBy, isNull);
    });
  });
}
