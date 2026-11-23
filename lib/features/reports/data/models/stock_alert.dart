/// Low stock alert item for the "Low stock" tab.
///
/// [reorderLevel] is not a number anyone typed: it is the computed reorder
/// target -- enough stock to cover [coverageDays] at the item's observed
/// [unitsPerDay], floored at the store's low-stock threshold (see
/// `reorderTarget` in `../domain/reorder_velocity.dart`). [deficit] is
/// therefore "how many units short of covering the coverage window", which is
/// what a reorder list is for, rather than "below an invented constant".
class StockAlert {
  const StockAlert({
    required this.name,
    required this.currentStock,
    required this.reorderLevel,
    this.category,
    this.unitsPerDay,
    this.coverageDays,
    this.isStockUncounted = false,
  });

  final String name;
  final int currentStock;
  final int reorderLevel;
  final String? category;

  /// The item's observed selling rate, when a velocity source was available.
  /// Null means the alert was built without velocity data (a hand-constructed
  /// one in a test, or a repository that could not load any sales history).
  final double? unitsPerDay;

  /// The window [reorderLevel] covers, when velocity was involved.
  final int? coverageDays;

  /// True when nobody has counted this line's shelf.
  ///
  /// [currentStock] reads as 0 for such a line, but 0 is a count and null is
  /// not: "never counted" is its own problem and callers that sum deficits
  /// exclude these, or a fresh import would report the whole catalogue short.
  final bool isStockUncounted;

  /// Whether this item is critically low (below reorder level).
  bool get isCritical => currentStock <= reorderLevel;

  /// How many units below reorder level (positive when below).
  int get deficit => reorderLevel - currentStock;

  /// The rate rendered the way a tile would: one decimal below ten, whole
  /// numbers at or above it, and nothing when no rate is known.
  String? get formattedUnitsPerDay {
    final rate = unitsPerDay;
    if (rate == null) return null;
    return rate < 10 ? rate.toStringAsFixed(1) : rate.round().toString();
  }

  String get formattedCurrent => currentStock.toString();
  String get formattedReorder => reorderLevel.toString();
}
