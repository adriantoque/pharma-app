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
      final suggestions = matcher.suggestFor('paracetamol 125');

      expect(suggestions.first.medicine.name, 'paracetamol 125');
      expect(suggestions.first.confidence, 1.0);
    });

    test('ignores case and stray punctuation', () {
      expect(bestName('  Paracetamol 125. '), 'paracetamol 125');
    });
  });

  group('a misread', () {
    test('still finds the medicine', () {
      expect(bestName('Bingesic'), 'Biogesic');
      expect(bestName('decolmgen'), 'decolgen');
    });

    test('accepts a name written with extra letters', () {
      // Edit distance alone scores "amox" against "amoxcilln" too low to offer
      // it, and a shared "cilln" handed the name to a different drug.
      expect(bestName('Amoxcilln'), 'Amox');
    });

    test('accepts a name written with the form left off', () {
      expect(bestName('Alag ad'), 'ALAGAD CAP');
    });

    test('accepts a dose that was left off', () {
      expect(bestName('Salbutamol'), 'Salbutamol 4mg');
    });
  });

  group('a short name', () {
    test('does not outrank the entry the whole reading names', () {
      // "Amox" is a real entry and does match, but "amox 500" names the
      // strength, so the entry that accounts for the whole reading has to come
      // first or the user is quoted the wrong price.
      final suggestions = matcher.suggestFor('Amox 500', limit: 5);
      final bare = suggestions.firstWhere((s) => s.medicine.name == 'Amox');

      expect(suggestions.first.medicine.name, 'Amox 500mg');
      expect(
        suggestions.first.confidence,
        greaterThan(bare.confidence),
        reason: 'the strength-bearing entry is the better explanation',
      );
    });
  });

  group('ranking', () {
    test('offers the strongest match first', () {
      final suggestions = matcher.suggestFor('Cetirizine');

      expect(suggestions.first.medicine.name, 'Cetirizine');
      expect(suggestions.first.confidence, greaterThan(0.9));
    });

    test('lists an exact match ahead of a near miss', () {
      final suggestions = matcher.suggestFor('Alcohol');

      expect(suggestions.first.medicine.name, 'Alcohol');
      expect(suggestions.length, greaterThan(1));
    });

    test('caps how many it offers', () {
      expect(matcher.suggestFor('Amox', limit: 2), hasLength(2));
    });

    test('keeps same-named entries at different prices apart', () {
      final prices = matcher
          .suggestFor('Diatabs', limit: 5)
          .map((s) => s.medicine.priceCentavos)
          .toList();

      // Two entries share the name "DIATABS" at different prices, so collapsing
      // by name would hide one of them.
      expect(prices, containsAll(<int>[700, 1100, 2200]));
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
          const RecognizedLine('Amox 500mg'),
          const RecognizedLine('Biogesic'),
          const RecognizedLine('Paracetamol 125'),
        ],
        perLine: 1,
      );

      expect(
        suggestions.map((s) => s.medicine.name),
        ['Amox 500mg', 'Biogesic', 'paracetamol 125'],
      );
      expect(suggestions.map((s) => s.lineIndex), [0, 1, 2]);
    });

    test('offers alternatives within a line', () {
      final suggestions = matcher.suggest(
        [const RecognizedLine('Diatabs')],
        perLine: 3,
      );

      // "Diatabs" is three products at three prices, so one line can be more
      // than one suggestion.
      expect(suggestions, hasLength(3));
      expect(suggestions.every((s) => s.lineIndex == 0), isTrue);
    });

    test('offers a medicine named twice only once', () {
      final suggestions = matcher.suggest([
        const RecognizedLine('Biogesic'),
        const RecognizedLine('Biogesic'),
      ], perLine: 1);

      expect(suggestions, hasLength(1));
    });

    test('keeps the lines in the order they were read', () {
      final suggestions = matcher.suggest([
        const RecognizedLine('nope zzz'),
        const RecognizedLine('Biogesic'),
      ]);

      expect(suggestions.single.lineIndex, 1);
    });
  });

  group('candidates', () {
    test('lets the catalog pick the right one out of several readings', () {
      // The recognizer's own first choice is wrong, but the second reading
      // names a real medicine exactly, so it is the one worth showing.
      final suggestions = matcher.suggest(
        [const RecognizedLine('Amox 500ng'), const RecognizedLine('Amox 500mg')],
      );

      expect(suggestions.first.medicine.name, 'Amox 500mg');
    });

    test('still matches when the top reading is nonsense', () {
      final suggestions = matcher.suggest(
        [const RecognizedLine('qwerty'), const RecognizedLine('decolgen')],
      );

      expect(suggestions.single.medicine.name, 'decolgen');
    });

    test('skips a line that recognised nothing', () {
      final suggestions = matcher.suggest([
        const RecognizedLine(''),
        const RecognizedLine('Biogesic'),
      ]);

      expect(suggestions.single.medicine.name, 'Biogesic');
    });
  });

  group('threshold', () {
    test('a stricter threshold drops the weaker suggestions', () {
      // "Bingesic" is a misread, so nothing about it is exact enough to keep.
      expect(matcher.suggestFor('Bingesic', threshold: 0.99), isEmpty);
    });

    test('an exact name survives the strictest threshold', () {
      expect(
        matcher.suggestFor('Biogesic', threshold: 0.99),
        hasLength(1),
      );
    });
  });
}
