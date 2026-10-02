import '../models/order_line_model.dart';
import '../../../search/data/models/medicine_model.dart';

/// How one order line is written down, and read back.
///
/// A codec in its own right because there are now two places that store a
/// basket -- Firestore for a signed-in account, preferences for offline mode --
/// and a draft that one of them writes and the other cannot read is a basket
/// that silently empties. One format, one implementation.
///
/// The stored shape is the medicine's *identity* rather than its whole record.
/// Stock, aliases and expiry are state the price list owns and may have moved
/// on since, so copying them into a draft would resurrect a count from whenever
/// the order was started. Whoever restores a draft puts the identity back into
/// the live catalogue, which brings the current count with it.
abstract final class OrderLineCodec {
  /// One line as stored.
  static Map<String, dynamic> toMap(OrderLineModel line) => {
    'name': line.medicine.name,
    'priceCentavos': line.medicine.priceCentavos,
    'quantity': line.quantity,
  };

  static List<Map<String, dynamic>> listToMaps(
    Iterable<OrderLineModel> lines,
  ) => [for (final line in lines) toMap(line)];

  /// A whole stored basket, skipping the lines that cannot be read.
  static List<OrderLineModel> readList(Object? raw) {
    if (raw is! List) return const <OrderLineModel>[];
    return [for (final entry in raw) ?readLine(entry)];
  }

  /// One stored line back, or null for one that cannot be used.
  ///
  /// Silent about the skips, for the same reason the price-list parser is: a
  /// basket with a bad line in it is still worth restoring, and a line that
  /// cannot be read is one the user can see and remove.
  static OrderLineModel? readLine(Object? entry) {
    if (entry is! Map) return null;
    final name = entry['name'];
    final price = readIntOrNull(entry['priceCentavos']);
    final quantity = readIntOrNull(entry['quantity']);
    if (name is! String || name.isEmpty || price == null || quantity == null) {
      return null;
    }
    // A zero or negative quantity is not a line -- see [OrderLineModel], where a
    // removal is represented by the line not being there. Reading one back would
    // resurrect a deletion the user had already made.
    if (quantity < 1) return null;

    // `stock` is deliberately null. The live catalogue decides what this may be
    // ordered in quantity; a count read out of a draft is a count from whenever
    // the order was started and may be hours and several other counts out of date.
    return OrderLineModel(
      medicine: MedicineModel(name: name, priceCentavos: price, stock: null),
      quantity: quantity,
    );
  }

  /// A whole number, or null when [value] is not one.
  static int? readIntOrNull(Object? value) => switch (value) {
    int v => v,
    num v => v.round(),
    String v => int.tryParse(v),
    _ => null,
  };
}
