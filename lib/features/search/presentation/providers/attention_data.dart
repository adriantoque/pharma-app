import '../../data/models/medicine_model.dart';

class AttentionData {
  const AttentionData({required this.lowStock});

  final List<MedicineModel> lowStock;

  int get total => lowStock.length;

  factory AttentionData.of(List<MedicineModel> all) {
    final lowStock = <MedicineModel>[];

    for (final medicine in all) {
      if (medicine.isLowStock) lowStock.add(medicine);
    }

    return AttentionData(lowStock: lowStock);
  }
}
