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
