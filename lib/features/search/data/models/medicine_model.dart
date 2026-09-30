import '../../../../core/utils/currency.dart';

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
  });

  /// Display name, stored exactly as the pharmacy writes it. The source list
  /// contains misspellings (`amplodiphine`, `Omegaazole`) that are left alone
  /// deliberately: a wrong drug name in a pharmacy app is worse than an ugly
  /// one, so correcting them is a decision for the pharmacist, not the code.
  final String name;

  /// Price in centavos. Integer rather than a double so a price with centavos
  /// (there is one: 2.50) is stored exactly and never drifts.
  final int priceCentavos;

  /// Units on the shelf.
  ///
  /// Required rather than defaulted: an implicit level would be an invented one,
  /// and a pharmacy app that quietly guesses how much of a drug it has is worse
  /// than one that has nothing to show.
  ///
  /// Deliberately *not* part of [operator ==]. Stock is state, not identity. A
  /// line added while an item was at 10 must still be found after the count
  /// moves to 9, or every quantity lookup and removal starts silently missing.
  final int stock;

  /// At or below this, an item is called out as running low.
  ///
  /// Lives on the model rather than in a widget so the search list, the quantity
  /// sheet and anything built later cannot disagree about what "low" means.
  static const int lowStockThreshold = 5;

  /// Nothing on the shelf, so the item cannot be put in an order at all.
  bool get isOutOfStock => stock == 0;

  /// Low but still orderable. Zero is excluded on purpose: "no stock" and "a
  /// little stock" are different problems and get different wording.
  bool get isLowStock => stock > 0 && stock <= lowStockThreshold;

  /// `₱4.00`. Built from integer arithmetic instead of dividing a double, so
  /// there is no floating-point rounding to reason about.
  String get formattedPrice => formatCentavos(priceCentavos);

  /// The stock line under the name on a search row, and the colour to show it
  /// in. Returned together so a row cannot render a healthy label in the error
  /// colour.
  (String, bool) get stockLine => switch (stock) {
    0 => ('Out of stock', true),
    <= lowStockThreshold => ('$stock in stock · low', true),
    _ => ('$stock in stock', false),
  };

  /// Two entries are the same item when the name and the price both match, per
  /// the class doc: `Amox` at 4.00 is not `Amox` at 45.00, and `DIATABS` at
  /// 11.00 is not `Diatabs` at 7.00 even though only the capitalisation differs.
  ///
  /// [stock] is excluded on purpose; see its doc comment.
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
  /// Two ways to hit:
  /// 1. The name contains the query, case- and space-insensitively, so `amox`
  ///    finds `Amox`, `Amox 250 CAP` and `Amox 500mg`.
  /// 2. The query looks like a price, so typing `65` or `65.00` at the counter
  ///    lists everything priced that way.
  ///
  /// Bare one- and two-digit numbers are treated as *name* matches only. If they
  /// also matched prices, `amox` would be fine but a stray `4` would dump every
  /// 4-peso item on the shelf, which is noise rather than a lookup.
  bool matches(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return true;

    final needle = _normalise(trimmed);
    if (_normalise(name).contains(needle)) return true;

    if (_priceQuery(trimmed) case final centavos?) {
      return priceCentavos == centavos;
    }
    return false;
  }

  /// Lowercases and strips spaces, so `Baby Oil` is findable by typing
  /// `babyoil` as well as `baby oil`.
  static String _normalise(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');

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
