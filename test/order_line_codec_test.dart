import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/orders/data/models/order_line_model.dart';
import 'package:pharmaguide/features/orders/data/repositories/order_line_codec.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';

void main() {
  test('preserves product ID and package type in a saved order line', () {
    const line = OrderLineModel(
      medicine: MedicineModel(
        productId: '101',
        name: 'Paracetamol',
        packageType: 'Box (100s)',
        priceCentavos: 15000,
        stock: 20,
      ),
      quantity: 2,
    );

    final restored = OrderLineCodec.readLine(OrderLineCodec.toMap(line));

    expect(restored?.medicine.productId, '101');
    expect(restored?.medicine.packageType, 'Box (100s)');
    expect(restored?.medicine.documentId, line.medicine.documentId);
    expect(restored?.quantity, 2);
    expect(restored?.medicine.stock, isNull);
  });
}
