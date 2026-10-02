import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../search/data/models/medicine_model.dart';
import '../../search/data/repositories/medicine_repository.dart';
import '../domain/prescription_recognizer.dart';

/// A catalog medicine that a scanned line could plausibly be naming.
@immutable
class PrescriptionSuggestion {
  const PrescriptionSuggestion({
    required this.medicine,
    required this.confidence,
    this.lineIndex,
  });

  final MedicineModel medicine;

  /// How closely the line fits [medicine], from 0 to 1. This is a judgement
  /// about the catalog, not ML Kit's own score, which the plugin documents as
  /// populated only for models that support it.
  final double confidence;

  /// The line this came from, or null when the reading was typed rather than
  /// scanned.
  final int? lineIndex;
}

/// Decides which catalog entry a scanned line is naming.
///
/// The recognizer's own ranking is a good guess at generic text but a poor one
/// for a short list of known medicines, so the catalog does the deciding here:
/// scoring each line against every entry and taking the best is what turns a
/// noisy reading such as "Amoxcilln 500" into the right medicine, because the
/// catalog is the cheapest possible check on which reading was correct.
///
/// Scoring is a blend of two comparisons, and the better of the two wins:
/// whole-string edit distance, which is forgiving about a wrong character but
/// blind to word boundaries, and per-word matching, which survives a misread
/// dose or a stray space. A reading that shares nothing with a name scores
/// nothing, so the [defaultThreshold] is what stops an unrelated suggestion
/// from being offered rather than an empty result.
class PrescriptionMatcher {
  PrescriptionMatcher(this.repository);

  /// The whole price list to match against.
  final MedicineRepository repository;

  /// How alike two strings have to be before a suggestion is offered. Tuned so
  /// "Amoxcilln 500" matches "amoxicillin 500" while a bare "500" does not
  /// match anything.
  static const double defaultThreshold = 0.6;

  /// Beyond this length, edit distance is skipped and a plain containment test
  /// is used instead. A misread longer than this is not a medicine name, and
  /// the comparison is quadratic.
  static const int _maxCompareLength = 64;

  /// How alike two strings count when one contains the other.
  ///
  /// High enough to clear [defaultThreshold] and be offered, low enough that an
  /// exact match still wins. Every case measured against the catalog leaves a
  /// clear gap between the two, so the exact number does not matter much.
  static const double _containmentScore = 0.75;

  /// The shortest fragment allowed to count as containment, in characters.
  static const int _minContainmentLength = 4;

  static final RegExp _hasLetter = RegExp('[a-z]');

  /// Suggests medicines for every scanned line, in the order they were read.
  ///
  /// A medicine is offered once even if several lines name it, so the list is a
  /// set of candidates to choose from rather than a transcription. The user
  /// still taps it as many times as the prescription calls for.
  List<PrescriptionSuggestion> suggest(
    List<RecognizedLine> lines, {
    int perLine = 3,
    double threshold = defaultThreshold,
  }) {
    final catalog = _catalog();
    final suggestions = <PrescriptionSuggestion>[];
    final seen = <MedicineModel>{};

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      for (final suggestion in _rank(
        catalog,
        lines[lineIndex].text,
        limit: perLine,
        threshold: threshold,
        lineIndex: lineIndex,
      )) {
        if (seen.add(suggestion.medicine)) suggestions.add(suggestion);
      }
    }

    return suggestions;
  }

  /// Suggests medicines for one line of text.
  ///
  /// Used for a corrected reading and for the manual search box, which is why
  /// there is no line to point at.
  List<PrescriptionSuggestion> suggestFor(
    String text, {
    int limit = 3,
    double threshold = defaultThreshold,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    return _rank(_catalog(), trimmed, limit: limit, threshold: threshold);
  }

  /// The price list with its names normalised once, rather than once per reading
  /// per line.
  List<({MedicineModel medicine, String normalised, List<String> tokens})>
  _catalog() {
    return [
      for (final medicine in repository.all())
        (
          medicine: medicine,
          normalised: _normalise(medicine.name),
          tokens: [
            for (final token in _tokens(medicine.name)) _normalise(token),
          ],
        ),
    ];
  }

  /// The best-matching catalog entries for one line, strongest first.
  List<PrescriptionSuggestion> _rank(
    List<({MedicineModel medicine, String normalised, List<String> tokens})>
    catalog,
    String reading, {
    required int limit,
    required double threshold,
    int? lineIndex,
  }) {
    final normalisedReading = _normalise(reading);
    if (normalisedReading.isEmpty) return const [];
    final readingTokens = [
      for (final token in _tokens(reading)) _normalise(token),
    ];

    final best = <MedicineModel, double>{};
    for (final entry in catalog) {
      if (entry.normalised.isEmpty) continue;

      final score = _similarity(
        normalisedReading,
        readingTokens,
        entry.normalised,
        entry.tokens,
      );
      if (score < threshold) continue;

      final current = best[entry.medicine];
      if (current == null || score > current) best[entry.medicine] = score;
    }

    final ranked = best.entries.toList()
      ..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        // Ties broken by name so the same input always offers the same order.
        return byScore != 0
            ? byScore
            : a.key.name.toLowerCase().compareTo(b.key.name.toLowerCase());
      });

    return [
      for (final entry in ranked.take(limit))
        PrescriptionSuggestion(
          medicine: entry.key,
          lineIndex: lineIndex,
          confidence: entry.value,
        ),
    ];
  }

  /// The closer of a whole-string and a per-word comparison.
  ///
  /// The per-word score is the *worse* of the two directions, not the average.
  /// Averaging let a short name match perfectly on its one word and score full
  /// marks against a longer reading -- "Amox" scored 1.0 for the reading
  /// "amox 500", which would have outranked the correct "Amox 500mg" on a
  /// prescription. Requiring the reading's words to be accounted for as well is
  /// what stops a name that is merely a prefix from winning.
  static double _similarity(
    String reading,
    List<String> readingTokens,
    String name,
    List<String> nameTokens,
  ) {
    var score = _ratio(reading, name);

    // Extra characters are the most common thing a scanned name gets wrong,
    // but they hurt a short name badly: "amox" against "amoxcilln" is
    // only 0.44, so a real match like "Amox" dropped below the threshold
    // entirely and "Cloxacillin" won on a shared "cilln". Containment is the
    // evidence that both are the same word, so it acts as a floor.
    if (_contains(reading, name)) {
      score = math.max(score, _containmentScore);
    }

    if (nameTokens.isEmpty || readingTokens.isEmpty) return score;

    final perWord = math.min(
      _coverage(nameTokens, readingTokens),
      _coverage(readingTokens, nameTokens),
    );

    return math.max(score, perWord);
  }

  /// Whether one of the two strings is a substring of the other, in a way that
  /// indicates the same word written with more or fewer characters.
  ///
  /// The shorter string has to be a real word fragment: a bare dose such as
  /// "500" sits inside "Amox 500mg" but naming it from a number alone is
  /// nonsense, and "12" sits inside "125" without meaning anything by it.
  static bool _contains(String reading, String name) {
    final shorter = reading.length <= name.length ? reading : name;
    final longer = reading.length <= name.length ? name : reading;

    if (shorter.length < _minContainmentLength) return false;
    if (!_hasLetter.hasMatch(shorter)) return false;

    return longer.contains(shorter);
  }

  /// How much of [words] the other list accounts for: each word scored against
  /// its closest counterpart, then averaged.
  static double _coverage(List<String> words, List<String> against) {
    var matched = 0.0;
    for (final word in words) {
      var closest = 0.0;
      for (final candidate in against) {
        final score = _ratio(word, candidate);
        if (score > closest) closest = score;
      }
      matched += closest;
    }
    return matched / words.length;
  }

  /// Strips everything but letters and digits.
  ///
  /// Deliberately stricter than `MedicineModel.matches`, which only drops
  /// whitespace: a misread arrives with stray punctuation and dropped spaces,
  /// and a dose is kept because names such as "paracetamol 125" carry it.
  static String _normalise(String value) =>
      value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  /// Splits text into its words, on anything that is not a letter or a digit.
  static List<String> _tokens(String value) => [
    for (final match in RegExp('[a-z0-9]+').allMatches(value.toLowerCase()))
      match.group(0)!,
  ];

  /// Two strings' similarity, from 0 to 1, as one minus their edit distance
  /// relative to the longer of the two.
  static double _ratio(String a, String b) {
    if (a == b) return 1;
    if (a.isEmpty || b.isEmpty) return 0;

    if (a.length > _maxCompareLength || b.length > _maxCompareLength) {
      return a.contains(b) || b.contains(a) ? 0.5 : 0;
    }

    final longest = math.max(a.length, b.length);
    return (longest - _editDistance(a, b)) / longest;
  }

  static int _editDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
        final insertion = current[j - 1] + 1;
        final deletion = previous[j] + 1;
        current[j] = math.min(substitution, math.min(insertion, deletion));
      }
      final swap = previous;
      previous = current;
      current = swap;
    }

    return previous[b.length];
  }
}
