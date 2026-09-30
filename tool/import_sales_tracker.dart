// Offline importer: reads `Daily Sales Tracker.xlsx` and writes the seed data
// the app loads into Firestore.
//
//   dart run tool/import_sales_tracker.dart
//
// Run from the repository root. Nothing here ships in the app: the workbook is
// a build-time input, and the app reads JSON, never a spreadsheet.
//
// Outputs, all under `tool/out/`:
//   medicines_seed.json     the price list, one entry per (name, price) pair
//   sales_seed.json         every sale line, for the reports screen
//   merge_review.csv        name merges, flagged applied or needs-review
//   excluded_sources.json   sheets left out, with the reason and the raw rows
//   junk_candidates.json    lines kept as sales but not offered as products
//
// The point of the two review files is that nothing in the source is silently
// dropped. A line the tool will not turn into a product is still recorded as a
// sale, and a sheet it will not read at all is written out with the rows it
// skipped, so a person can disagree with any of it and recover the line.

import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';

/// Workbook to read, relative to the repository root.
const String sourceFile = 'Daily Sales Tracker.xlsx';

/// Directory the generated files are written to.
const String outputDir = 'tool/out';

/// Sales run from July to September, and the workbook records no year anywhere,
/// so it is stated here rather than guessed. Change this when the next year's
/// sheets land.
const int salesYear = 2025;

/// Sheets holding named-customer orders rather than counter trade.
///
/// They are real sales and are imported as such, tagged [SaleKind.bulk] so the
/// daily-trend report can leave them out. A single `Losartan+Amlodipine` line of
/// 260 units is worth more than a whole day at the counter, and averaging it in
/// would flatten every ordinary day next to it.
const Set<String> bulkSheets = {'STEVEN ORDER', 'TITA RITA'};

/// Sheets deliberately not read, and why. Surfaced in `excluded_sources.json`
/// so a disagreement is a one-line fix rather than an argument about whether
/// the data was looked at.
const Map<String, String> excludedSheets = {
  'Copy of August 1_conflict186732':
      'Partial Google Sheets conflict copy. None of its 9 lines match August 1 '
          'on item and quantity, it holds one line with no price, and it '
          'contains "daphne pills" at 147 pesos which appears nowhere else in '
          'eleven months of records. Not merged in; the raw rows are in this '
          'file for review.',
  'EFRAIM':
      'Unfinished draft, not a record: all 65 lines have quantity 5, none has a '
          'total, and the prices carry a stray prefix that never parsed.',
  'BOSE OUT OF STOCK August':
      'A purchase order for items to buy in, not sales and not a stock count.',
  'ITEMS':
      'A reference master of brand/generic/classification. Read to fill in '
          'generic names, never as a source of products: it covers only 17 of '
          'the 463 distinct names actually sold.',
};

/// Longest raw item name accepted, as a guard against a merged cell or a stray
/// note being read as a product.
const int maxNameLength = 60;

/// Real products that are commonly confused with a lookalike, as normalised keys.
///
/// Edit distance cannot tell a typo from a different drug that happens to look
/// almost the same, and on this data that mistake is not hypothetical: it folded
/// `clarizine` (loratadine, sold as Clarinex) into `cinarizine` (cinnarizine),
/// and earlier it wanted to fold Ambroxol into Amoxicillin, Betadine into
/// Bonamine, Colchicine into Calamine, Strepsils into Stresstabs and Solmux into
/// Symdex. Each pair is two or three edits apart, which is the same distance as
/// `mefanamic` is from `mefenamic`.
///
/// When *both* names on a pair appear here, the merge is refused, because two
/// known products are not one product whatever their spelling. When only one
/// does, the other is a misspelling of it and the merge is allowed, which is
/// what keeps `cinarizine` folding into `cinnarizine` while `clarizine` stays
/// its own line.
///
/// Only correct product names belong in this list, never their misspellings.
/// A pharmacist should extend it; it is a clinical judgement, not a fuzzy-match
/// setting.
const Set<String> distinctProductNames = {
  'ambroxol',
  'amoxicillin',
  'amlodipine',
  'betadine',
  'bonamine',
  'calamine',
  'ceelin',
  'cetirizine',
  'cinnarizine',
  'clarinex',
  'clarizine',
  'colchicine',
  'loratadine',
  'losartan',
  'paracetamol',
  'pluradec',
  'salbutamol',
  'solmux',
  'strepsils',
  'stresstabs',
  'symdex',
};

void main(List<String> args) {
  final file = File(sourceFile);
  if (!file.existsSync()) {
    stderr.writeln('Cannot find $sourceFile. Run this from the repository root.');
    exitCode = 1;
    return;
  }

  final excel = Excel.decodeBytes(file.readAsBytesSync());
  final generics = _readGenericNames(excel);

  final sales = <SaleLine>[];
  final skippedSheets = <String, _SkippedSheet>{};

  for (final entry in excel.tables.entries) {
    final name = entry.key;
    final sheet = entry.value;
    if (sheet == null) continue;

    final reason = excludedSheets[name];
    if (reason != null) {
      skippedSheets[name] = _SkippedSheet(
        reason: reason,
        rows: _rawRows(sheet),
      );
      continue;
    }

    final kind = bulkSheets.contains(name) ? SaleKind.bulk : SaleKind.counter;
    final date = kind == SaleKind.bulk ? null : _dateFromSheetName(name);
    if (kind == SaleKind.counter && date == null) {
      skippedSheets[name] = _SkippedSheet(
        reason: 'Sheet name is not a date, so it cannot be placed in history.',
        rows: _rawRows(sheet),
      );
      continue;
    }

    for (final line in _readSalesSheet(sheet, name, kind, date)) {
      sales.add(line);
    }
  }

  final result = _buildCatalog(sales, generics);
  _write(result, skippedSheets);
  _writeSales(sales);

  _report(result, skippedSheets, sales);
}

/// The kind of trade a sale line came from.
enum SaleKind {
  /// Ordinary walk-in trade on a daily sheet.
  counter,

  /// A named bulk order, excluded from the daily average.
  bulk,
}

/// One line read off a sheet.
class SaleLine {
  const SaleLine({
    required this.sheet,
    required this.kind,
    required this.date,
    required this.rawName,
    required this.quantity,
    required this.priceCentavos,
  });

  final String sheet;
  final SaleKind kind;

  /// Null for bulk orders, which have no day of their own.
  final DateTime? date;

  /// The name exactly as written, because a wrong drug name in a pharmacy app
  /// is worse than an ugly one.
  final String rawName;

  /// Units sold, kept as written rather than rounded to a whole number. Two
  /// lines in the workbook record half a tablet, which cannot be right, and
  /// rounding them off quietly would bury that; they are reported for review in
  /// `fractional_quantity.json` with the exact value kept.
  final num quantity;
  final int priceCentavos;

  bool get hasFractionalQuantity => quantity != quantity.roundToDouble();

  int get lineTotalCentavos => (quantity * priceCentavos).round();

  String get key => _normalise(rawName);
}

/// A sheet the tool declined to import, kept so nothing disappears silently.
class _SkippedSheet {
  const _SkippedSheet({required this.reason, required this.rows});

  final String reason;
  final List<Map<String, String>> rows;
}

/// The comparison key for a name: lower case, letters and digits only.
///
/// `Amox 500mg`, `amox500mg` and `AMOX-500MG` are one name written three ways.
/// This is the same normalisation the app searches with, so a key here is a key
/// there.
String _normalise(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// The digits in a name, in order, which stand for its strength and form.
///
/// `para125` and `para250` are different products, and `amlo10` is not a way of
/// spelling `amox`. Any merge is refused unless the digits agree exactly, which
/// is what keeps a strength change from being read as a typo.
String _digitSignature(String value) =>
    value.replaceAll(RegExp('[^0-9]'), '');

/// The date in a sheet name, or null if it is not one.
///
/// The names are not tidy: `Sept 2 ` carries a trailing space, `Septermber 14`
/// is a typo, and `AUGUST 19 TODAY` has a note glued on the end. Matching the
/// month on its first three letters survives all three.
DateTime? _dateFromSheetName(String name) {
  final letters = name.replaceAll(RegExp('[^a-zA-Z]'), '');
  final digits = RegExp('[0-9]+').allMatches(name).map((m) => m.group(0)!);

  const monthPrefixes = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  if (letters.length < 3) return null;
  final month = monthPrefixes[letters.substring(0, 3).toLowerCase()];
  if (month == null) return null;

  final dayText = digits.isEmpty ? null : digits.first;
  final day = dayText == null ? null : int.tryParse(dayText);
  if (day == null || day < 1 || day > 31) return null;

  return DateTime(salesYear, month, day);
}

/// Cell text, or null for an empty cell.
///
/// The package models a cell as a sealed hierarchy with no shared accessor, and
/// the totals column holds a formula rather than a result, so this is the one
/// place the shapes are taken apart.
String? _text(Data? cell) {
  final value = cell?.value;
  if (value == null) return null;
  if (value is TextCellValue) {
    final span = value.value.toString();
    return span.isEmpty ? null : span;
  }
  if (value is IntCellValue) return value.value.toString();
  if (value is DoubleCellValue) return value.value.toString();
  if (value is BoolCellValue) return value.value.toString();
  if (value is FormulaCellValue) return null;
  return value.toString();
}

/// A number in a cell, tolerating the stray characters some sheets carry.
num? _number(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(RegExp('[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  return num.tryParse(cleaned);
}

/// Reads the sale rows off a sheet.
///
/// Data starts at row 7 on every sheet, including the two that have no header
/// row at all, so the row number is fixed rather than searched for. Columns are
/// B item, C quantity, D unit price, and the total in E is deliberately ignored:
/// on most rows it is a formula the reader cannot evaluate, and recomputing
/// quantity times price is both simpler and checkable.
List<SaleLine> _readSalesSheet(
  Sheet sheet,
  String sheetName,
  SaleKind kind,
  DateTime? date,
) {
  final rows = sheet.rows;
  final lines = <SaleLine>[];

  for (var r = 6; r < rows.length; r++) {
    final row = rows[r];
    if (row.length < 4) continue;

    final name = _text(row[1])?.trim();
    if (name == null || name.isEmpty) continue;
    // Header text repeated, or a summary label rather than a product.
    if (RegExp(r'^(item|total|grand)', caseSensitive: false).hasMatch(name)) {
      continue;
    }
    if (name.length > maxNameLength) continue;

    final quantity = _number(_text(row[2]));
    final price = _number(_text(row[3]));
    // A line with neither a count nor a price records no sale. Anything less
    // than that is a half-filled row, and guessing a unit price would invent
    // the single number the rest of the app depends on.
    if (quantity == null && price == null) continue;

    lines.add(
      SaleLine(
        sheet: sheetName,
        kind: kind,
        date: date,
        rawName: name,
        quantity: quantity ?? 0,
        priceCentavos: ((price ?? 0) * 100).round(),
      ),
    );
  }
  return lines;
}

/// The raw rows of a sheet, for the excluded-sheets report.
List<Map<String, String>> _rawRows(Sheet sheet) {
  final out = <Map<String, String>>[];
  for (final row in sheet.rows) {
    final cells = <String, String>{};
    for (var c = 0; c < row.length; c++) {
      final t = _text(row[c]);
      if (t != null) {
        cells[String.fromCharCode(65 + c)] = t;
      }
    }
    if (cells.isNotEmpty) out.add(cells);
  }
  return out;
}

/// Brand-to-generic names from the `ITEMS` master sheet.
///
/// A pharmacy sells a brand and its generic as separate products at separate
/// prices, so these are recorded as a pointer rather than merged together. The
/// sheet is small and only covers a fraction of what is actually sold, which is
/// fine: it is a hint, and a missing one costs nothing.
Map<String, String> _readGenericNames(Excel excel) {
  final sheet = excel.tables['ITEMS'];
  if (sheet == null) return const {};

  final out = <String, String>{};
  // Row 1 is the header and row 2 a sub-header, so the data starts at row 3.
  for (var r = 2; r < sheet.rows.length; r++) {
    final row = sheet.rows[r];
    if (row.length < 3) continue;
    final brand = _text(row[1])?.trim();
    final generic = _text(row[2])?.trim();
    if (brand == null || brand.isEmpty) continue;
    if (generic == null || generic.isEmpty) continue;
    // A cell holding the word "Generic" is a label, not a product.
    if (_normalise(generic) == 'genericname') continue;
    out.putIfAbsent(_normalise(brand), () => generic);
  }
  return out;
}

/// A name cluster: one canonical spelling plus the ways it is also written.
class _NameCluster {
  _NameCluster(this.canonical, this.units);

  final String canonical;
  double units;

  /// Every raw spelling seen, most-used first. The first is the canonical name.
  final List<_Spelling> spellings = [];

  int get members => spellings.length;
}

class _Spelling {
  _Spelling(this.raw);

  final String raw;

  /// Units, as a double because two lines record a fraction of a unit.
  double units = 0;
  int occurrences = 0;
  int? lastPriceCentavos;
  DateTime? lastSeen;
}

/// The result of turning sales lines into a catalogue.
class _ImportResult {
  _ImportResult({
    required this.products,
    required this.clusters,
    required this.merges,
    required this.junk,
  });

  final List<Map<String, Object?>> products;
  final List<_NameCluster> clusters;

  /// Every cluster with more than one spelling, whether merged automatically or
  /// sent for review.
  final List<_MergeRow> merges;

  /// Names too short or too thin to be products, kept as sales only.
  final List<Map<String, Object?>> junk;
}

/// One row of `merge_review.csv`.
class _MergeRow {
  _MergeRow({
    required this.canonical,
    required this.members,
    required this.units,
    required this.applied,
    required this.reason,
  });

  final String canonical;
  final List<String> members;
  final double units;
  final bool applied;
  final String reason;
}

_ImportResult _buildCatalog(
  List<SaleLine> sales,
  Map<String, String> generics,
) {
  // 1. Collapse raw spellings into keys, counting units as we go so the
  //    canonical spelling can be the one the counter actually uses.
  final byKey = <String, _Spelling>{};
  for (final sale in sales) {
    final spelling = byKey.putIfAbsent(
      sale.key,
      () => _Spelling(sale.rawName),
    );
    spelling.units += sale.quantity.toDouble();
    spelling.occurrences += 1;
    spelling.lastPriceCentavos = sale.priceCentavos;
    if (sale.date != null) {
      final seen = sale.date!;
      if (spelling.lastSeen == null || seen.isAfter(spelling.lastSeen!)) {
        spelling.lastSeen = seen;
      }
    }
  }

  // 2. Group keys into clusters, most-used first so the canonical name is the
  //    spelling staff reach for. A key joins a cluster only when it is directly
  //    close to that cluster's canonical name, never merely to another member:
  //    chaining is how a threshold like this quietly turns one drug into seven.
  final clusters = <_NameCluster>[];
  final byCanonical = <String, _NameCluster>{};

  // The real product names are seeded first, so a misspelling of one becomes an
  // alias of that product and never a product in its own right. Without this,
  // `cinarizine` -- a typo of Cinnarizine, but sold often enough to be the most
  // used spelling -- would win the canonical slot, and `clarizine`, a different
  // drug entirely, would then look like a typo of *it* and be folded in.
  final claimed = <String>{};
  for (final protected in distinctProductNames) {
    final cluster = _NameCluster(protected, 0);
    final members = <_Spelling>[];
    for (final spelling in byKey.values) {
      if (_normalise(spelling.raw) == protected) {
        members.add(spelling);
        claimed.add(_normalise(spelling.raw));
      }
    }
    if (members.isEmpty) continue;
    for (final spelling in members) {
      if (spelling.occurrences == 0) continue;
      cluster.spellings.add(spelling);
      cluster.units += spelling.units;
    }
    // Only keep it if the workbook actually sells that name; otherwise the
    // cluster would be empty and would stand in for a product nobody stocks.
    if (cluster.spellings.isEmpty) continue;
    clusters.add(cluster);
    byCanonical[protected] = cluster;
  }

  final ordered = byKey.values.toList()
    ..sort((a, b) {
      final byUnits = b.units.compareTo(a.units);
      return byUnits != 0 ? byUnits : a.raw.compareTo(b.raw);
    });

  for (final spelling in ordered) {
    // Already placed as an alias of a known product.
    if (claimed.contains(_normalise(spelling.raw))) continue;

    _NameCluster? target;
    for (final cluster in clusters) {
      if (_isSafeMerge(cluster.canonical, spelling.raw)) {
        target = cluster;
        break;
      }
    }
    if (target == null) {
      target = _NameCluster(spelling.raw, spelling.units);
      clusters.add(target);
    }

    target.spellings.add(spelling);
    target.units += spelling.units;
    byCanonical[_normalise(target.canonical)] = target;
  }

  // 3. Decide each cluster's status, then build one product per price.
  final merges = <_MergeRow>[];
  final junk = <Map<String, Object?>>[];
  final products = <Map<String, Object?>>[];

  for (final cluster in clusters) {
    cluster.spellings.sort((a, b) {
      final byUnits = b.units.compareTo(a.units);
      return byUnits != 0 ? byUnits : a.raw.compareTo(b.raw);
    });
    final canonical = cluster.spellings.first;
    final others = cluster.spellings.skip(1).map((s) => s.raw).toList();

    var applied = false;
    String reason;
    if (cluster.members == 1) {
      reason = 'single spelling';
    } else if (_isSafeMerge(canonical.raw, cluster.spellings[1].raw) &&
        cluster.spellings.every((s) => _isSafeMerge(canonical.raw, s.raw))) {
      applied = true;
      reason = 'auto: within 2 edits, same strength';
    } else {
      reason = _describeWhyNot(canonical.raw, cluster.spellings[1].raw);
    }

    if (cluster.members > 1) {
      merges.add(
        _MergeRow(
          canonical: canonical.raw,
          members: [canonical.raw, ...others],
          units: cluster.units,
          applied: applied,
          reason: reason,
        ),
      );
    }

    if (!_looksLikeProduct(canonical.raw)) {
      for (final spelling in cluster.spellings) {
        junk.add({
          'name': spelling.raw,
          'key': _normalise(spelling.raw),
          'units': spelling.units,
          'occurrences': spelling.occurrences,
          'reason': 'too short or too few letters to be a product name',
        });
      }
      continue;
    }

    final genericKey = generics[_normalise(canonical.raw)];
    final aliases = others.where((s) => s != canonical.raw).toList();

    // 4. One product per distinct price, because the app identifies a line by
    //    name *and* price: `Amox` at 4.00 and at 45.00 are two products, and
    //    merging them would lose a real price point.
    final prices = <int>{};
    for (final sale in sales) {
      if (sale.key == _normalise(canonical.raw)) prices.add(sale.priceCentavos);
    }
    // A cluster can hold several keys, so also collect each member's prices.
    for (final spelling in cluster.spellings) {
      for (final sale in sales) {
        if (sale.key == _normalise(spelling.raw)) {
          prices.add(sale.priceCentavos);
        }
      }
    }

    final sortedPrices = prices.toList()..sort();
    for (final price in sortedPrices) {
      products.add({
        'name': canonical.raw,
        'priceCentavos': price,
        // Nobody has counted the shelf. Null, not zero: a pharmacy app that
        // reports an invented stock level is worse than one that admits it has
        // not been told.
        'stock': null,
        'expiryDate': null,
        'aliases': aliases,
        'genericKey': genericKey,
        'meta': {
          'units': cluster.units,
          'spellings': cluster.spellings.map((s) => s.raw).toList(),
          'lastSeen': canonical.lastSeen?.toIso8601String().substring(0, 10),
        },
      });
    }
  }

  products.sort((a, b) {
    final byName = (a['name']! as String)
        .toLowerCase()
        .compareTo((b['name']! as String).toLowerCase());
    return byName != 0 ? byName : (a['priceCentavos']! as int).compareTo(b['priceCentavos']! as int);
  });

  merges.addAll(_nearMisses(clusters));

  return _ImportResult(
    products: products,
    clusters: clusters,
    merges: merges,
    junk: junk,
  );
}

/// Pairs of names that are close enough to be worth a person's attention but too
/// far apart to merge on their own.
///
/// Without this, a spelling that is three edits from a real product simply
/// becomes an orphan line in the catalogue and nobody is ever shown it. That is
/// exactly the case a pharmacist should confirm: `cinarizine` really is a
/// different drug from `ceterizine`, and the code is right to keep them apart,
/// but it is not the code's call to make, and a silent split is the worst of
/// both worlds.
///
/// Two categories, both narrow on purpose. Anything looser produces thousands of
/// pairs nobody will ever read, and a review list that long is a review list
/// that gets skipped.
List<_MergeRow> _nearMisses(List<_NameCluster> clusters) {
  final rows = <_MergeRow>[];
  final byName = <String, _NameCluster>{
    for (final c in clusters) c.canonical: c,
  };

  // 1. The same letters with a different strength: `para125` beside `para250`,
  //    `salbutamol2` beside `salbutamol4`. These are the dangerous ones, because
  //    they look like a typo and merging them would quietly halve or double a
  //    real product's price. Grouping by the letters keeps the search small.
  final byLetters = <String, List<_NameCluster>>{};
  for (final cluster in clusters) {
    final letters = _letterSignature(cluster.canonical);
    if (letters.length < 4) continue;
    byLetters.putIfAbsent(letters, () => []).add(cluster);
  }
  for (final group in byLetters.values) {
    for (var i = 0; i < group.length; i++) {
      for (var j = i + 1; j < group.length; j++) {
        final a = group[i];
        final b = group[j];
        if (_digitSignature(a.canonical) == _digitSignature(b.canonical)) {
          continue; // Same strength, so handled by the normal merge rule.
        }
        rows.add(
          _MergeRow(
            canonical: a.canonical,
            members: [a.canonical, b.canonical],
            units: a.units < b.units ? a.units : b.units,
            applied: false,
            reason: 'auto: NOT MERGED, same name at a different strength '
                '(${_describeDigits(a.canonical)} vs ${_describeDigits(b.canonical)}) '
                '-- these are separate products, confirm before any merge',
          ),
        );
      }
    }
  }

  // 2. Same strength, three or four edits apart: a plausible typo of a real
  //    product that the two-edit rule is not confident enough to fold in.
  for (final a in clusters) {
    if (a.canonical.length < 5) continue;
    for (final b in clusters) {
      if (identical(a, b) || b.canonical.length < 5) continue;
      if (_digitSignature(a.canonical) != _digitSignature(b.canonical)) {
        continue;
      }
      if ((a.canonical.length - b.canonical.length).abs() > 2) continue;
      if (byName[b.canonical] == null) continue;

      final distance = _editDistance(a.canonical, b.canonical);
      if (distance < 3 || distance > 4) continue;

      rows.add(
        _MergeRow(
          canonical: a.canonical,
          members: [a.canonical, b.canonical],
          units: a.units < b.units ? a.units : b.units,
          applied: false,
          reason: 'auto: NOT MERGED, $distance edits apart at the same strength '
              '-- one of these may be a misspelling of the other',
        ),
      );
    }
  }
  return rows;
}

/// The letters in a name, which stand for the drug and the word.
String _letterSignature(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z]'), '');

String _describeDigits(String raw) {
  final digits = _digitSignature(raw);
  return digits.isEmpty ? 'no strength' : digits;
}

/// Whether two spellings are close enough to be treated as one name.
///
/// Two edits is the whole rule, plus the digits having to agree. An earlier
/// attempt reused the app's `PrescriptionMatcher` threshold and it folded
/// Amoxicillin together with Ambroxol and with Amlodipine, Losartan with
/// Loratadine, and Strepsils with Stresstabs. That matcher snaps a bad reading
/// onto a catalogue that is already known to be right; here both sides are
/// unchecked counter handwriting, so a loose threshold invents products.
///
/// The digit test is what stops a strength change reading as a typo, which is
/// the difference between `para125` and `para250`.
bool _isSafeMerge(String a, String b) {
  // Compared case-insensitively. The counter writes some lines in capitals and
  // the same line in lower case on another day, and `CETERIZINE` against
  // `cetirizine` is one product, not two. The name that is kept for display is
  // whichever the counter writes most, so this does not tidy the spelling, it
  // only stops a capitalisation difference creating a second price-list line.
  final left = a.toLowerCase();
  final right = b.toLowerCase();
  if (left == right) return true;
  // Short strings are too easy to collide by accident: `z` and `bl` sit an edit
  // from half a dozen real drug names.
  if (left.length < 5 || right.length < 5) return false;
  if (_digitSignature(left) != _digitSignature(right)) return false;
  if ((left.length - right.length).abs() > 2) return false;
  // Two known products stay two products. See [distinctProductNames].
  if (distinctProductNames.contains(_normalise(left)) &&
      distinctProductNames.contains(_normalise(right))) {
    return false;
  }
  return _editDistance(left, right) <= 2;
}

/// Why a pair was not merged, in words a pharmacist can act on.
String _describeWhyNot(String a, String b) {
  if (_digitSignature(a) != _digitSignature(b)) {
    return 'auto: REFUSED, different strength (${_digitSignature(a).isEmpty ? 'none' : _digitSignature(a)} '
        'vs ${_digitSignature(b).isEmpty ? 'none' : _digitSignature(b)})';
  }
  return 'auto: REFUSED, ${_editDistance(a, b)} edits apart';
}

/// Levenshtein distance, capped by the caller to small strings.
int _editDistance(String a, String b) {
  if (a == b) return 0;
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
      current[j] = substitution < insertion
          ? (substitution < deletion ? substitution : deletion)
          : (insertion < deletion ? insertion : deletion);
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}

/// Whether a name is plausibly a product, as opposed to a stray keystroke.
bool _looksLikeProduct(String raw) {
  final key = _normalise(raw);
  if (key.length < 4) return false;
  final letters = raw.replaceAll(RegExp('[^a-zA-Z]'), '');
  // `z`, `bl`, `rdl1` and the like: real lines in the workbook, but not drugs.
  return letters.length >= 3;
}

void _write(_ImportResult result, Map<String, _SkippedSheet> skipped) {
  final out = Directory(outputDir);
  if (!out.existsSync()) out.createSync(recursive: true);

  File('$outputDir/medicines_seed.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(result.products)}\n',
  );

  File('$outputDir/merge_review.csv').writeAsStringSync(_mergeCsv(result.merges));
  File('$outputDir/junk_candidates.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(result.junk)}\n',
  );

  // The sheets the tool would not read, with the rows it skipped, so a
  // decision to exclude can be checked or reversed without re-opening the
  // workbook and re-deriving the reasoning.
  File('$outputDir/excluded_sources.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
          for (final entry in skipped.entries)
            entry.key: {'reason': entry.value.reason, 'rows': entry.value.rows},
        })}\n',
  );
}

/// Writes every sale line, for the reports screen.
///
/// The raw name travels with each line rather than a reference to a product, so
/// history stays readable even for a name that was too thin to become a
/// product, and so a later rename of a product does not rewrite what was
/// actually sold on the day.
void _writeSales(List<SaleLine> sales) {
  const encoder = JsonEncoder.withIndent('  ');
  final rows = [
    for (final sale in sales)
      {
        'date': sale.date?.toIso8601String().substring(0, 10),
        'kind': sale.kind.name,
        'rawName': sale.rawName,
        'key': sale.key,
        'quantity': sale.quantity,
        'priceCentavos': sale.priceCentavos,
        'totalCentavos': sale.lineTotalCentavos,
        'sourceSheet': sale.sheet,
      },
  ];
  File('$outputDir/sales_seed.json').writeAsStringSync('${encoder.convert(rows)}\n');

  // Half a tablet is not a quantity a pharmacy can dispense, so these two lines
  // are data-entry errors rather than sales. They are written out with the exact
  // figure instead of being rounded into a whole unit, because rounding them
  // would make the reports confidently wrong.
  final fractional = [
    for (final sale in sales.where((s) => s.hasFractionalQuantity))
      {
        'sheet': sale.sheet,
        'date': sale.date?.toIso8601String().substring(0, 10),
        'rawName': sale.rawName,
        'quantity': sale.quantity,
        'priceCentavos': sale.priceCentavos,
        'note': 'fractional unit count; kept as written, not rounded',
      },
  ];
  File('$outputDir/fractional_quantity.json').writeAsStringSync(
    '${encoder.convert(fractional)}\n',
  );
}

String _mergeCsv(List<_MergeRow> merges) {
  final buffer = StringBuffer()
    ..writeln('applied,units,canonical,members,reason');
  // Applied first, so the glance at the top of the file is the set of automatic
  // decisions; everything below needs a person.
  final ordered = merges.toList()
    ..sort((a, b) {
      if (a.applied != b.applied) return a.applied ? -1 : 1;
      return b.units.compareTo(a.units);
    });
  for (final row in ordered) {
    buffer.writeln(
      [
        row.applied ? 'yes' : 'no',
        row.units,
        _csv(row.canonical),
        _csv(row.members.join(' | ')),
        _csv(row.reason),
      ].join(','),
    );
  }
  return buffer.toString();
}

String _csv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

void _report(
  _ImportResult result,
  Map<String, _SkippedSheet> skipped,
  List<SaleLine> sales,
) {
  final counter = sales.where((s) => s.kind == SaleKind.counter);
  final bulk = sales.where((s) => s.kind == SaleKind.bulk);

  int centavos(Iterable<SaleLine> lines) =>
      lines.fold(0, (sum, l) => sum + l.lineTotalCentavos);

  double units(Iterable<SaleLine> lines) =>
      lines.fold(0.0, (sum, l) => sum + l.quantity);

  final applied = result.merges.where((m) => m.applied).toList();
  final review = result.merges.where((m) => !m.applied).toList();
  final fractional = sales.where((s) => s.hasFractionalQuantity).toList();

  stdout
    ..writeln('Read $sourceFile')
    ..writeln('')
    ..writeln('  counter sheets   ${counter.length} lines, '
        '${_units(units(counter))} units, ${_peso(centavos(counter))}')
    ..writeln('  bulk orders      ${bulk.length} lines, '
        '${_units(units(bulk))} units, ${_peso(centavos(bulk))}')
    ..writeln('')
    ..writeln('  price list       ${result.products.length} lines '
        'from ${result.clusters.where((c) => c.members > 1).length} merged names')
    ..writeln('  merges applied   ${applied.length} '
        '(covering ${_units(applied.fold(0.0, (s, m) => s + m.units))} units)')
    ..writeln('  near misses to review ${review.length} pairs '
        'left unmerged on purpose')
    ..writeln('  kept as sales only ${result.junk.length} short or thin names')
    ..writeln('  fractional quantities ${fractional.length} '
        '(kept as written, listed in fractional_quantity.json)')
    ..writeln('')
    ..writeln('  sheets not read:');
  skipped.forEach((name, detail) {
    stdout.writeln('    $name -- ${detail.reason}');
  });
  stdout
    ..writeln('')
    ..writeln('  wrote $outputDir/medicines_seed.json, sales_seed.json, '
        'merge_review.csv, excluded_sources.json, junk_candidates.json');
}

String _peso(int centavos) => 'P${(centavos / 100).toStringAsFixed(2)}';

/// Units, without a trailing `.0` on the whole numbers.
String _units(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
