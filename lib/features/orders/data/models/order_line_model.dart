import '../../../../core/utils/currency.dart';
import '../../../search/data/models/medicine_model.dart';

/// One line of the current order: a medicine and how many of it.
///
/// Immutable, so the provider can swap a whole line rather than mutate one in
/// place, and a widget that read a line cannot be surprised by it changing
/// underneath.
class OrderLineModel {
  const OrderLineModel({required this.medicine, required this.quantity});

  final MedicineModel medicine;

  /// Always at least 1. Zero is represented by the line not existing, so there
  /// is no such thing as a zero-quantity line to render or total up.
  final int quantity;

  /// `price × quantity` in centavos, as integer multiplication.
  int get totalCentavos => medicine.priceCentavos * quantity;

  /// `₱135.00`, the price of this line on its own.
  String get formattedTotal => formatCentavos(totalCentavos);

  /// `₱45.00 × 3`, the unit price alongside how many, which is how the line is
  /// read out loud at the counter.
  String get formattedQuantity => '${medicine.formattedPrice} × $quantity';

  OrderLineModel copyWith({MedicineModel? medicine, int? quantity}) {
    return OrderLineModel(
      medicine: medicine ?? this.medicine,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderLineModel &&
          other.medicine == medicine &&
          other.quantity == quantity;

  @override
  int get hashCode => Object.hash(medicine, quantity);
}
