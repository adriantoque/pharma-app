import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/scan/data/prescription_matcher.dart';
import 'package:pharmaguide/features/scan/domain/prescription_recognizer.dart';
import 'package:pharmaguide/features/search/data/repositories/medicine_repository.dart';

void main() {
  const repository = StaticMedicineRepository();
  final matcher = PrescriptionMatcher(repository);

  String? bestName(String text) =>
      matcher.suggestFor(text).firstOrNull?.medicine.name;

  group('an exact name', () {
    test('matches itself with full confidence', () {
      final suggestions = matcher.suggestFor('Bioflu Tablet');

      expect(suggestions.first.medicine.name, 'Bioflu Tablet');
      expect(suggestions.first.confidence, 1.0);
    });

    test('ignores case and stray punctuation', () {
      expect(bestName('  Bioflu Tablet. '), 'Bioflu Tablet');
    });
  });

  group('a misread', () {
    test('still finds the medicine', () {
      // A plural slip on the form is the kind of thing a scan produces, and
      // the per-word comparison is what keeps it above the threshold.
      expect(
        bestName('Biogesic 500mg Tablets'),
        'Biogesic 500mg Tablet (Paracetamol)',
      );
    });

    test('accepts a name written with the dose left off', () {
      expect(
        bestName('Medicol Advance Softgel'),
        'Medicol Advance 200mg Softgel',
      );
    });

    test('accepts a name written with the form left off', () {
      // "Amoxil 500mg Capsule" is the whole name up to its generic, so
      // containment carries it even though the tail is missing.
      expect(
        bestName('Amoxil 500mg Capsule'),
        'Amoxil 500mg Capsule (Amoxicillin)',
      );
    });
  });

  group('ranking', () {
    test('offers the strongest match first', () {
      final suggestions = matcher.suggestFor('Bioflu Tablet');

      expect(suggestions.first.medicine.name, 'Bioflu Tablet');
      expect(suggestions.first.confidence, greaterThan(0.9));
    });

    test('lists an exact match ahead of a near miss', () {
      final suggestions = matcher.suggestFor(
        'Paracetamol 500mg (Generic Tablet)',
      );

      expect(suggestions.first.medicine.name, 'Paracetamol 500mg (Generic Tablet)');
      expect(suggestions.first.confidence, 1.0);
      expect(suggestions.length, greaterThan(1));
    });

    test('caps how many it offers', () {
      expect(matcher.suggestFor('Cetirizine', limit: 2), hasLength(2));
    });

    test('keeps same-named entries at different prices apart', () {
      final prices = matcher
          .suggestFor('Diatabs', limit: 5)
          .map((s) => s.medicine.priceCentavos)
          .toList();

      // Three entries share the name "Diatabs 2mg Capsule (Loperamide)" at
      // different prices, so collapsing by name would hide two of them.
      expect(prices, containsAll(<int>[800, 7800, 75000]));
    });
  });

  group('nonsense', () {
    test('offers nothing for a number alone', () {
      expect(matcher.suggestFor('500'), isEmpty);
    });

    test('offers nothing for empty text', () {
      expect(matcher.suggestFor(''), isEmpty);
      expect(matcher.suggestFor('   '), isEmpty);
    });

    test('offers nothing for unrelated words', () {
      expect(matcher.suggestFor('zzzqqq'), isEmpty);
    });
  });

  group('a whole prescription', () {
    test('suggests one medicine per line, strongest first', () {
      // One suggestion per line, so this is only about which line wins.
      final suggestions = matcher.suggest(
        [
          const RecognizedLine('Biogesic 500mg Tablet (Paracetamol)'),
          const RecognizedLine('Bioflu Tablet'),
          const RecognizedLine('Diatabs 2mg Capsule (Loperamide)'),
        ],
        perLine: 1,
      );

      expect(
        suggestions.map((s) => s.medicine.name),
        [
          'Biogesic 500mg Tablet (Paracetamol)',
          'Bioflu Tablet',
          'Diatabs 2mg Capsule (Loperamide)',
        ],
      );
      expect(suggestions.map((s) => s.lineIndex), [0, 1, 2]);
    });

    test('offers alternatives within a line', () {
      final suggestions = matcher.suggest(
        [const RecognizedLine('Diatabs 2mg Capsule (Loperamide)')],
        perLine: 3,
      );

      // "Diatabs" is three packages at three prices, so one line can be more
      // than one suggestion.
      expect(suggestions, hasLength(3));
      expect(suggestions.every((s) => s.lineIndex == 0), isTrue);
    });

    test('offers a medicine named twice only once', () {
      final suggestions = matcher.suggest([
        const RecognizedLine('Bioflu Tablet'),
        const RecognizedLine('Bioflu Tablet'),
      ], perLine: 1);

      expect(suggestions, hasLength(1));
    });

    test('keeps the lines in the order they were read', () {
      final suggestions = matcher.suggest([
        const RecognizedLine('nope zzz'),
        const RecognizedLine('Bioflu Tablet'),
      ]);

      expect(suggestions.single.lineIndex, 1);
    });
  });

  group('candidates', () {
    test('lets the catalog pick the right one out of several readings', () {
      // The recognizer's own first choice is wrong, but the second reading
      // names a real medicine exactly, so it is the one worth showing.
      final suggestions = matcher.suggest(
        [const RecognizedLine('Bioflo'), const RecognizedLine('Bioflu Tablet')],
      );

      expect(suggestions.single.medicine.name, 'Bioflu Tablet');
    });

    test('still matches when the top reading is nonsense', () {
      final suggestions = matcher.suggest(
        [const RecognizedLine('qwerty'), const RecognizedLine('Bioflu Tablet')],
      );

      expect(suggestions.single.medicine.name, 'Bioflu Tablet');
    });

    test('skips a line that recognised nothing', () {
      final suggestions = matcher.suggest([
        const RecognizedLine(''),
        const RecognizedLine('Bioflu Tablet'),
      ]);

      expect(suggestions.single.medicine.name, 'Bioflu Tablet');
    });
  });

  group('threshold', () {
    test('a stricter threshold drops the weaker suggestions', () {
      // The plural slip is not exact, so nothing about it clears a strict bar.
      expect(matcher.suggestFor('Biogesic 500mg Tablets', threshold: 0.99), isEmpty);
    });

    test('an exact name survives the strictest threshold', () {
      expect(
        matcher.suggestFor('Bioflu Tablet', threshold: 0.99),
        hasLength(1),
      );
    });
  });
}
