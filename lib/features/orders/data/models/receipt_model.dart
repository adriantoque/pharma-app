import 'package:meta/meta.dart';

import 'order_history_model.dart';

/// One receipt's worth of data, ready to be rendered on screen or to PDF.
///
/// The fields mirror what appears on a thermal receipt, and every money value
/// is stored as integer centavos, matching the rest of the app.
///
/// An [OrderHistory] does not carry payment detail or store branding, so a
/// [ReceiptModel] is assembled from the order plus the live store settings
/// and the signed-in cashier, right before rendering. Use [fromOrder] to build
/// one from a completed order.
@immutable
class ReceiptModel {
  const ReceiptModel({
    required this.receiptId,
    required this.orderId,
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    required this.cashierName,
    required this.dateTime,
    required this.paymentMethod,
    required this.items,
    required this.subtotalCentavos,
    required this.discountCentavos,
    required this.taxCentavos,
    required this.totalCentavos,
    this.cashTenderedCentavos,
    this.changeCentavos,
  });

  /// Builds a [ReceiptModel] from a completed [order], using the store's
  /// name/address/phone for the header and [cashierName] for the till line.
  ///
  /// The receipt id defaults to the order id with an `R` prefix so a receipt
  /// can be distinguished from its source order in a file name.
  factory ReceiptModel.fromOrder({
    required OrderHistory order,
    required String storeName,
    required String? storeAddress,
    required String? storePhone,
    required String cashierName,
    String paymentMethod = 'Cash',
  }) {
    final items = order.items.map((line) => ReceiptItem(
      name: line.medicine.name,
      quantity: line.quantity,
      unitPriceCentavos: line.medicine.priceCentavos,
      totalCentavos: line.totalCentavos,
    )).toList(growable: false);

    return ReceiptModel(
      receiptId: 'R${order.id}',
      orderId: order.id,
      storeName: storeName,
      storeAddress: storeAddress ?? '',
      storePhone: storePhone ?? '',
      cashierName: cashierName,
      dateTime: order.time,
      paymentMethod: paymentMethod,
      items: items,
      subtotalCentavos: order.totalCentavos,
      discountCentavos: 0,
      taxCentavos: 0,
      totalCentavos: order.totalCentavos,
    );
  }

  /// Unique id for this receipt, also the file name when saved to disk.
  final String receiptId;

  /// The source order's id, so the receipt can be traced back.
  final String orderId;

  /// The pharmacy's name, from store settings (falls back to the app name).
  final String storeName;

  /// The pharmacy's address, from store settings (may be empty).
  final String storeAddress;

  /// The pharmacy's phone number, from store settings (may be empty).
  final String storePhone;

  /// The signed-in cashier's name.
  final String cashierName;

  /// When the order was completed.
  final DateTime dateTime;

  /// How the customer paid (e.g. "Cash", "GCash", "Card").
  final String paymentMethod;

  /// One line per item on the receipt.
  final List<ReceiptItem> items;

  /// Sum of line totals before discount and tax, in centavos.
  final int subtotalCentavos;

  /// Discount given, in centavos.
  final int discountCentavos;

  /// Tax (VAT) added, in centavos.
  final int taxCentavos;

  /// Final amount due, in centavos.
  final int totalCentavos;

  /// How much the customer handed over, in centavos. Null when not paying
  /// by cash (or when the amount was never recorded).
  final int? cashTenderedCentavos;

  /// Change due back to the customer, in centavos. Null when not applicable.
  final int? changeCentavos;

  /// `₱180.00`, the grand total formatted for display.
  String get formattedTotal => '₱${(totalCentavos ~/ 100)}.${(totalCentavos % 100).toString().padLeft(2, '0')}';

  /// `Nov 23, 2026 • 2:45 PM`, a compact date-time for the receipt header.
  String get formattedDateTime {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} • $hour12:$minute $period';
  }

  /// A file-system-safe name for the saved PDF.
  String get fileName => 'receipt_$receiptId.pdf';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptModel &&
          other.receiptId == receiptId &&
          other.orderId == orderId &&
          other.storeName == storeName &&
          other.storeAddress == storeAddress &&
          other.storePhone == storePhone &&
          other.cashierName == cashierName &&
          other.dateTime == dateTime &&
          other.paymentMethod == paymentMethod &&
          other.items == items &&
          other.subtotalCentavos == subtotalCentavos &&
          other.discountCentavos == discountCentavos &&
          other.taxCentavos == taxCentavos &&
          other.totalCentavos == totalCentavos &&
          other.cashTenderedCentavos == cashTenderedCentavos &&
          other.changeCentavos == changeCentavos;

  @override
  int get hashCode => Object.hash(
        receiptId,
        orderId,
        storeName,
        storeAddress,
        storePhone,
        cashierName,
        dateTime,
        paymentMethod,
        Object.hashAll(items),
        subtotalCentavos,
        discountCentavos,
        taxCentavos,
        totalCentavos,
        cashTenderedCentavos,
        changeCentavos,
      );

  @override
  String toString() =>
      'ReceiptModel(id: $receiptId, order: $orderId, total: $totalCentavos, items: ${items.length})';
}

/// One line on a receipt: a medicine, how many, and what it cost.
@immutable
class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPriceCentavos,
    required this.totalCentavos,
  });

  /// The medicine's name as printed on the receipt.
  final String name;

  /// How many units were sold.
  final int quantity;

  /// The price of one unit, in centavos.
  final int unitPriceCentavos;

  /// `quantity × unitPrice`, in centavos.
  final int totalCentavos;

  /// `₱45.00 × 3`, how the line is read out at the counter.
  String get formattedQuantity =>
      '₱${(unitPriceCentavos ~/ 100)}.${(unitPriceCentavos % 100).toString().padLeft(2, '0')} × $quantity';

  /// `₱135.00`, the line's own total.
  String get formattedTotal =>
      '₱${(totalCentavos ~/ 100)}.${(totalCentavos % 100).toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptItem &&
          other.name == name &&
          other.quantity == quantity &&
          other.unitPriceCentavos == unitPriceCentavos &&
          other.totalCentavos == totalCentavos;

  @override
  int get hashCode => Object.hash(name, quantity, unitPriceCentavos, totalCentavos);

  @override
  String toString() => 'ReceiptItem(name: $name, qty: $quantity, total: $totalCentavos)';
}
