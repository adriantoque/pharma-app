import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/admin/data/models/store_settings_model.dart';

void main() {
  group('defaults', () {
    test('match what the app did before settings existed', () {
      const settings = StoreSettingsModel();

      expect(settings.name, isEmpty);
      expect(settings.address, isNull);
      expect(settings.phone, isNull);
      expect(settings.openMinutes, 8 * 60);
      expect(settings.closeMinutes, 17 * 60);

      // The threshold is the one the stock rows used to be compiled against,
      // so a store that never opens the settings screen sees no change.
      expect(
        settings.lowStockThreshold,
        StoreSettingsModel.defaultLowStockThreshold,
      );
      expect(
        settings.expiryWarningDays,
        StoreSettingsModel.defaultExpiryWarningDays,
      );
      expect(
        StoreSettingsModel.defaultExpiryWarningDays,
        90,
        reason: 'the Expiring Meds screen showed ninety days before this '
            'became a setting; the default preserves that',
      );
      expect(
        settings.reorderCoverageDays,
        StoreSettingsModel.defaultReorderCoverageDays,
      );
      expect(
        StoreSettingsModel.defaultReorderCoverageDays,
        14,
        reason: 'the middle of the choice list: long enough to ride out a '
            "supplier's lead time on the fast movers, short enough that the "
            'targets stay honest to recent demand',
      );
      expect(
        StoreSettingsModel.reorderCoverageChoices,
        [7, 14, 30],
        reason: 'a fixed list, like the expiry window choices, so the sheet '
            'offers sizes a store can actually reason about',
      );
    });
  });

  group('fromMap / toMap', () {
    test('round-trips every field', () {
      const settings = StoreSettingsModel(
        name: 'Rosedale Pharmacy',
        address: '12 Mabini St.',
        phone: '0917 000 0000',
        openMinutes: 7 * 60 + 30,
        closeMinutes: 18 * 60,
        lowStockThreshold: 12,
        expiryWarningDays: 60,
        reorderCoverageDays: 30,
        updatedBy: 'Administrator',
      );

      final restored = StoreSettingsModel.fromMap(settings.toMap());

      expect(restored, settings);
      expect(restored.updatedBy, 'Administrator');
      expect(restored.reorderCoverageDays, 30);
    });

    test('tolerates a document written before a field existed', () {
      final settings = StoreSettingsModel.fromMap({'name': 'Old doc'});

      // Missing fields fall back to defaults rather than crashing or storing
      // nulls that would have to be guarded at every reader.
      expect(settings.name, 'Old doc');
      expect(settings.openMinutes, StoreSettingsModel.defaultOpenMinutes);
      expect(settings.closeMinutes, StoreSettingsModel.defaultCloseMinutes);
      expect(
        settings.lowStockThreshold,
        StoreSettingsModel.defaultLowStockThreshold,
      );
      expect(
        settings.expiryWarningDays,
        StoreSettingsModel.defaultExpiryWarningDays,
      );
      expect(
        settings.reorderCoverageDays,
        StoreSettingsModel.defaultReorderCoverageDays,
      );
    });

    test('tolerates a non-int coverage rather than storing it', () {
      // A console edit could put "14" as a string on the document; the
      // Firestore rules refuse it on write, and the reader falls back to the
      // default rather than crashing on the cast.
      final settings = StoreSettingsModel.fromMap({
        'reorderCoverageDays': '14',
      });

      expect(
        settings.reorderCoverageDays,
        StoreSettingsModel.defaultReorderCoverageDays,
      );
    });

    test('tolerates an out-of-range time rather than storing it', () {
      // A hand edit in the console is the one writer the validators cannot
      // reach; a minutes value of 90000 would render as a nonsense clock.
      final settings = StoreSettingsModel.fromMap({
        'openMinutes': 90000,
        'closeMinutes': -5,
      });

      expect(settings.openMinutes, StoreSettingsModel.defaultOpenMinutes);
      expect(settings.closeMinutes, StoreSettingsModel.defaultCloseMinutes);
    });
  });

  group('validationProblems', () {
    test('a blank name is a problem', () {
      const settings = StoreSettingsModel();
      expect(settings.validationProblems(), isNotEmpty);
    });

    test('closing before opening is a problem', () {
      final settings = const StoreSettingsModel(name: 'A').copyWith(
        openMinutes: 17 * 60,
        closeMinutes: 8 * 60,
      );
      expect(
        settings.validationProblems().join(' '),
        contains('Closing time must be after opening time'),
      );
    });

    test('an out-of-range threshold is a problem', () {
      for (final bad in [0, -1, 100]) {
        final settings = const StoreSettingsModel(
          name: 'A',
        ).copyWith(lowStockThreshold: bad);
        expect(
          settings.validationProblems(),
          isNotEmpty,
          reason: '$bad should be refused',
        );
      }
    });

    test('sensible settings have no problems', () {
      const settings = StoreSettingsModel(
        name: 'Rosedale Pharmacy',
        lowStockThreshold: 10,
      );
      expect(settings.validationProblems(), isEmpty);
    });
  });

  group('equality', () {
    test('ignores the bookkeeping fields', () {
      // updatedAt and updatedBy are stamped by the writer, not set by the
      // admin; a save that changed nothing must not read as dirty because
      // the stamp moved.
      final a = const StoreSettingsModel(name: 'A').copyWith(
        updatedBy: 'Admin',
      );
      final b = const StoreSettingsModel(name: 'A').copyWith(
        updatedBy: 'Someone else',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs when a setting differs', () {
      const a = StoreSettingsModel(name: 'A');
      expect(a, isNot(a.copyWith(name: 'B')));
      expect(a, isNot(a.copyWith(lowStockThreshold: 9)));
    });
  });

  group('withCleared', () {
    test('clears an optional field, which copyWith cannot', () {
      const settings = StoreSettingsModel(
        name: 'A',
        address: '12 Mabini St.',
        phone: '0917',
      );

      final cleared = settings.withCleared(clearAddress: true);

      expect(cleared.address, isNull);
      // The untouched field stays.
      expect(cleared.phone, '0917');
    });
  });

  group('formatMinutes', () {
    test('renders a twelve-hour clock', () {
      expect(StoreSettingsModel.formatMinutes(8 * 60), '8:00 AM');
      expect(StoreSettingsModel.formatMinutes(13 * 60 + 30), '1:30 PM');
      expect(StoreSettingsModel.formatMinutes(17 * 60), '5:00 PM');
    });

    test('midnight and noon read as twelve, not zero', () {
      expect(StoreSettingsModel.formatMinutes(0), '12:00 AM');
      expect(StoreSettingsModel.formatMinutes(12 * 60), '12:00 PM');
    });
  });
}
