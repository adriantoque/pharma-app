/// Low stock alert item for the "Low stock" tab.
class StockAlert {
  const StockAlert({
    required this.name,
    required this.currentStock,
    required this.reorderLevel,
    this.category,
  });

  final String name;
  final int currentStock;
  final int reorderLevel;
  final String? category;

  /// Whether this item is critically low (below reorder level).
  bool get isCritical => currentStock <= reorderLevel;

  /// How many units below reorder level (positive when below).
  int get deficit => reorderLevel - currentStock;

  String get formattedCurrent => currentStock.toString();
  String get formattedReorder => reorderLevel.toString();
}
