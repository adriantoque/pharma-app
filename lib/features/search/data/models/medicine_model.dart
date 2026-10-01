import '../../../../core/utils/currency.dart';

/// How much of a medicine is on the shelf.
///
/// [unknown] is a real state and not a missing value. The pharmacy's records
/// carry prices and sales but no stock counts, so an import knows what a thing
/// costs and nothing at all about how many are on the shelf. Reading that as
/// zero would put every product out of stock and make the price list useless;
/// reading it as some plausible number would be inventing a count nobody took.
/// It therefore stays visibly uncounted until a member of staff types one in.
enum StockState {
  /// Never counted. The item is orderable -- the shelf may well hold some -- but
  /// the app does not know, and says so instead of guessing.
  unknown,

  /// Counted, and the count is zero. The one state that blocks an order.
  outOfStock,

  /// Counted, and at or below [MedicineModel.lowStockThreshold].
  low,

  /// Counted, with room to spare.
  available,
}

/// One line in the pharmacy price list.
///
/// A line is identified by name *and* price: the source list has several
/// products sharing a shorthand name at different prices (`Amox` at both
/// 4.00 and 45.00), and those are separate items, not a conflict to resolve.
/// That rule is enforced by [operator ==] so anywhere an item is looked up --
/// an order line, say -- it comes out right without every call site repeating
/// the pair comparison.
class MedicineModel {
  const MedicineModel({
    required this.name,
    required this.priceCentavos,
    required this.stock,
    this.aliases = const [],
    this.genericKey,
    this.expiryDate,
  });

  /// Display name, stored exactly as the pharmacy writes it. The source list
  /// contains misspellings (`amplodiphine`, `Omegaazole`) that are left alone
  /// deliberately: a wrong drug name in a pharmacy app is worse than an ugly
  /// one, so correcting them is a decision for the pharmacist, not the code.
  final String name;

  /// Price in centavos. Integer rather than a double so a price with centavos
  /// (there is one: 2.50) is stored exactly and never drifts.
  final int priceCentavos;

  /// Units on the shelf, or null when nobody has counted them.
  ///
  /// Nullable rather than defaulted: an implicit level would be an invented one,
  /// and a pharmacy app that quietly guesses how much of a drug it has is worse
  /// than one that admits it does not know. See [StockState] for why the three
  /// states are kept apart, and [isStockUnknown] for the one callers most often
  /// want.
  ///
  /// Deliberately *not* part of [operator ==]. Stock is state, not identity. A
  /// line added while an item was at 10 must still be found after the count
  /// moves to 9, or every quantity lookup and removal starts silently missing.
  final int? stock;

  /// Other spellings the pharmacy has actually used for this same product, so
  /// searching the way staff write still finds it.
  ///
  /// Only ever *typos* of [name]: the counter writes `ceterizine` for the item
  /// the list calls `Cetirizine`, and both must resolve. A different drug is
  /// never an alias, however similar it looks -- `cinarizine` is not a way of
  /// spelling cetirizine, it is a different medicine, and folding the two
  /// together would hand out the wrong drug. Brands likewise stay separate lines
  /// and point at their generic through [genericKey] instead.
  ///
  /// Not part of identity either: `Cetirizine` and `Cetirizine` with `ceterizine`
  /// in its aliases are the same line, so [operator ==] would disagree with them.
  final List<String> aliases;

  /// Name of the generic this product is sold under, when it is a brand rather
  /// than a plain generic name. `Dolfenal` points at `diclofenac`.
  ///
  /// A pointer rather than an alias so the two stay independent products: a
  /// pharmacy stocks and prices the brand and the generic separately, and
  /// merging them would lose that. It does make search cross over, so typing
  /// either name finds both.
  final String? genericKey;

  /// When this line's stock expires, if anyone has recorded it.
  ///
  /// Nullable and hand-entered, because the records contain no expiry data at
  /// all. One date per line is a simplification: expiry really belongs to a
  /// batch, so a product held as two lots with different dates cannot be
  /// described here. It is accurate for the common single-lot case and wrong
  /// rather than approximate otherwise.
  final DateTime? expiryDate;

  /// At or below this, an item is called out as running low.
  ///
  /// Lives on the model rather than in a widget so the search list, the quantity
  /// sheet and anything built later cannot disagree about what "low" means.
  static const int lowStockThreshold = 5;

  /// Nothing on the shelf, so the item cannot be put in an order at all.
  ///
  /// False for an uncounted item. Not knowing how many are left is not the same
  /// as having none, and treating it as none would silently block ordering
  /// every product in a freshly imported catalogue.
  bool get isOutOfStock => stock == 0;

  /// Low but still orderable. Zero and unknown are excluded on purpose: "no
  /// stock" and "a little stock" are different problems and get different
  /// wording.
  bool get isLowStock => stock != null && stock! > 0 && stock! <= lowStockThreshold;

  /// True when nobody has counted this line yet, which is the normal state for
  /// an imported product and the one the inventory screen exists to fix.
  bool get isStockUnknown => stock == null;

  /// Days until [expiryDate], or null if there is no date or it has passed.
  ///
  /// Null covers both "no date recorded" and "already expired" so a caller
  /// sorting soonest-first treats a lapsed line as needing attention rather than
  /// putting it at an arbitrary distance. [isExpired] separates them.
  int? get daysUntilExpiry {
    final expiry = expiryDate;
    if (expiry == null) return null;
    final days = expiry.difference(_today()).inDays;
    return days >= 0 ? days : null;
  }

  bool get isExpired {
    final expiry = expiryDate;
    return expiry != null && expiry.isBefore(_today());
  }

  /// Midnight today, so a date stored at any time of day is not read as already
  /// a day gone. Injectable in tests through [asOf].
  static DateTime Function() _today = DateTime.now;

  /// Replaces the clock used by [daysUntilExpiry] and [isExpired]. Tests pass a
  /// fixed date so an expiry never drifts into a failure on a different day.
  // ignore: use_setters_to_change_properties
  static set debugToday(DateTime Function() clock) => _today = clock;

  /// The stock line under the name on a search row, and the state to colour it
  /// from. Returned together so a row cannot render a healthy label in the
  /// error colour.
  (String, StockState) get stockLine => switch (stockState) {
    StockState.unknown => ('Not counted', StockState.unknown),
    StockState.outOfStock => ('Out of stock', StockState.outOfStock),
    StockState.low => ('$stock in stock · low', StockState.low),
    StockState.available => ('$stock in stock', StockState.available),
  };

  /// Which of [StockState] this line is in, derived from [stock] alone.
  ///
  /// The single place the count is turned into a state, so [stockLine] and any
  /// caller sorting or filtering cannot disagree about what "low" means.
  StockState get stockState => switch (stock) {
    null => StockState.unknown,
    0 => StockState.outOfStock,
    <= lowStockThreshold => StockState.low,
    _ => StockState.available,
  };

  /// `₱4.00`. Built from integer arithmetic instead of dividing a double, so
  /// there is no floating-point rounding to reason about.
  String get formattedPrice => formatCentavos(priceCentavos);

  /// Stable Firestore document id for this line, derived from its identity.
  ///
  /// Derived rather than a Firestore auto-id because the price list is imported
  /// from a spreadsheet and the import will be re-run: an auto-id would give
  /// every import a fresh set of documents and leave the pharmacy holding
  /// several copies of one product, each with its own stock count. Hashing the
  /// identity makes a re-import an update instead.
  ///
  /// FNV-1a rather than [Object.hashCode], because a string's `hashCode` is only
  /// guaranteed stable within one process, and an id that moved between runs
  /// would re-create every document and orphan the stock counts again.
  ///
  /// The name goes in exactly as written, capitals included, so correcting a
  /// name yields a different id. That is deliberate: a corrected name is a
  /// different document, and retiring the old one is the pharmacist's call
  /// rather than something the app does silently.
  String get documentId {
    var hash = 0x811c9dc5;
    for (final unit in '$name|$priceCentavos'.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// The Firestore representation.
  ///
  /// `stock` and `expiryDate` are written as explicit nulls rather than omitted,
  /// so a document cannot keep a stale count from an earlier import that decided
  /// the line was uncounted.
  ///
  /// [documentId] is deliberately absent: the id is the document's path, and
  /// repeating it inside would be a second place for the same value to be wrong.
  Map<String, dynamic> toFirestore() => {
        'name': name,
        'priceCentavos': priceCentavos,
        'stock': stock,
        'aliases': aliases,
        'genericKey': genericKey,
        // A plain `yyyy-MM-dd` string rather than a Timestamp: a shelf expiry is
        // a date with no time of day, and a timestamp would invent one.
        'expiryDate': _formatDate(expiryDate),
      };

  /// Reads a document written by [toFirestore] or by the importer.
  ///
  /// Tolerates a missing or wrongly typed field -- a number stored as a double,
  /// a date as a Timestamp, an expiry as a Timestamp -- because a price list
  /// that came out of a spreadsheet is exactly the kind of data that arrives
  /// with the wrong type in one field. An unreadable field becomes null, which is
  /// the honest reading: the app cannot tell an uncounted item from one whose
  /// count it failed to parse, and both have to read as uncounted.
  factory MedicineModel.fromFirestore(Map<String, dynamic> data) {
    return MedicineModel(
      name: data['name'] as String? ?? '',
      priceCentavos: _readInt(data['priceCentavos']),
      // Read as nullable, unlike the price. A count that cannot be parsed is
      // *not* a count of zero, and reading it as one would mark a stocked item
      // out of stock on the strength of a bad field.
      stock: _readIntOrNull(data['stock']),
      aliases: [
        for (final alias in (data['aliases'] as List?) ?? const [])
          if (alias is String && alias.isNotEmpty) alias,
      ],
      genericKey: data['genericKey'] as String?,
      expiryDate: _readDate(data['expiryDate']),
    );
  }

  /// A whole number, or 0 when there is not one.
  ///
  /// Zero rather than null is right for a price: a line with no usable price is
  /// not a line anybody can sell, and it must still sort and compare. Stock does
  /// not get that luxury, which is why it goes through [_readIntOrNull].
  static int _readInt(Object? value) => _readIntOrNull(value) ?? 0;

  /// A whole number, or null when [value] is not one.
  static int? _readIntOrNull(Object? value) => switch (value) {
        int v => v,
        // Covers double as well, so it has to come after int but before nothing
        // else numeric.
        num v => v.round(),
        String v => int.tryParse(v),
        _ => null,
      };

  /// A shelf expiry, from either the `yyyy-MM-dd` string [toFirestore] writes or
  /// a Firestore Timestamp put there by hand in the console.
  static DateTime? _readDate(Object? value) => switch (value) {
        DateTime v => DateTime(v.year, v.month, v.day),
        String v => _parseDate(v),
        _ => null,
      };

  /// Parsed by hand rather than with [DateTime.parse] so an unpadded `2025-6-5`
  /// is still read, and so a value that is not a date at all yields null instead
  /// of throwing. An expiry that cannot be read shows as no expiry rather than
  /// as a wrong one.
  ///
  /// Anything after a `T` or a space is dropped first, so the full ISO form a
  /// document written outside this app arrives as -- `2027-03-09T14:30:00Z` --
  /// still resolves to 9 March, which is the date the pharmacist wrote down.
  static DateTime? _parseDate(String value) {
    final date = value.split(RegExp('[T ]')).first;
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  static String? _formatDate(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';

  /// A shelf expiry as the `yyyy-MM-dd` string that is stored, or null for none.
  ///
  /// Public because the store writes the expiry on its own, merging just that one
  /// key, and two places each formatting the date is how a line ends up stored
  /// two different ways.
  static String? formatExpiry(DateTime? value) => _formatDate(value);

  /// The same line with some fields replaced.
  ///
  /// Present for the optimistic update the provider paints before Firestore
  /// confirms: replacing the whole object is what makes that safe, because a
  /// model is immutable and there is nothing else for the store to write back
  /// into. Passing null for a field leaves it alone, so a caller cannot blank a
  /// stock count by omitting it -- clearing one is done with [setStock]'s own
  /// null, which is the one place a null means "no value".
  MedicineModel copyWith({
    String? name,
    int? priceCentavos,
    int? stock,
    List<String>? aliases,
    String? genericKey,
    DateTime? expiryDate,
  }) {
    return MedicineModel(
      name: name ?? this.name,
      priceCentavos: priceCentavos ?? this.priceCentavos,
      stock: stock ?? this.stock,
      aliases: aliases ?? this.aliases,
      genericKey: genericKey ?? this.genericKey,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }


  /// Two entries are the same item when the name and the price both match, per
  /// the class doc: `Amox` at 4.00 is not `Amox` at 45.00, and `DIATABS` at
  /// 11.00 is not `Diatabs` at 7.00 even though only the capitalisation differs.
  ///
  /// [stock] is excluded on purpose; see its doc comment. [aliases] and
  /// [genericKey] are excluded for the same reason: they are extra ways to find
  /// a line, not a second line.
  ///
  /// [hashCode] pairs the fields in the same order as [operator ==]; Dart's
  /// bit-mixing is commutative so the order is not load-bearing, but keeping them
  /// together is what makes the pair readable side by side.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineModel &&
          other.name == name &&
          other.priceCentavos == priceCentavos;

  @override
  int get hashCode => Object.hash(name, priceCentavos);

  /// The order a price list is shown in: alphabetical ignoring case, then
  /// cheapest first.
  ///
  /// The second key is what keeps a repeated name in a sensible order, so `Amox`
  /// reads 4.00 then 45.00 rather than arbitrarily. It lives on the model
  /// because the static list, the Firestore store and the provider all sort the
  /// same way, and three copies of a sort order is three chances for the list to
  /// come back in a different order depending on where it was read.
  static int compareByNameThenPrice(MedicineModel a, MedicineModel b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.priceCentavos.compareTo(b.priceCentavos);
  }

  /// Whether this item should appear for [query].
  ///
  /// Three ways to hit:
  /// 1. The name contains the query, case- and punctuation-insensitively, so
  ///    `amox` finds `Amox`, `Amox 250 CAP` and `Amox 500mg`.
  /// 2. An alias or the generic name contains it, so `ceterizine` and
  ///    `diclofenac` both find the `Cetirizine` and `Dolfenal` lines.
  /// 3. The query looks like a price, so typing `65` or `65.00` at the counter
  ///    lists everything priced that way.
  ///
  /// Bare one- and two-digit numbers are treated as *name* matches only. If they
  /// also matched prices, `amox` would be fine but a stray `4` would dump every
  /// 4-peso item on the shelf, which is noise rather than a lookup.
  bool matches(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return true;

    final needle = _normalise(trimmed);
    if (needle.isEmpty) return true;

    for (final candidate in searchableNames) {
      if (_normalise(candidate).contains(needle)) return true;
    }

    if (_priceQuery(trimmed) case final centavos?) {
      return priceCentavos == centavos;
    }
    return false;
  }

  /// Everything this line can be found by: its own name, the spellings the
  /// counter has used for it, and the generic a brand is sold under.
  ///
  /// One place so search and any later suggestion UI cannot disagree about
  /// which spellings count.
  Iterable<String> get searchableNames => [name, ...aliases, ?genericKey];

  /// Lowercases and drops everything that is not a letter or a digit, so `Baby
  /// Oil` is findable by typing `babyoil`, and `Amox 500mg` by `amox500mg`.
  static String _normalise(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Parses a query as a price in centavos, or null if it is not one.
  ///
  /// Accepts `65`, `65.00`, `65.5` and `₱65.00`. Requires at least two digits
  /// so a single keystroke does not start matching prices.
  static int? _priceQuery(String query) {
    final cleaned = query.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleaned.isEmpty || !RegExp(r'^\d{2,}(\.\d{1,2})?$').hasMatch(cleaned)) {
      return null;
    }
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    return (value * 100).round();
  }
}
