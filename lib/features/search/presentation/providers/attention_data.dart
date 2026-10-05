import 'package:flutter/material.dart';
import '../../data/models/medicine_model.dart';

class AttentionData {
  const AttentionData({
    required this.expired,
    required this.expiringSoon,
    required this.lowStock,
  });

  final int expired;
  final int expiringSoon;
  final List<MedicineModel> lowStock;

  int get total => expired + expiringSoon + lowStock.length;

  factory AttentionData.of(List<MedicineModel> all) {
    var expired = 0;
    var expiringSoon = 0;
    final lowStock = <MedicineModel>[];

    for (final medicine in all) {
      if (medicine.expiryDate != null) {
        if (medicine.isExpired) {
          expired++;
        } else if ((medicine.daysUntilExpiry ?? 31) <= 30) {
          expiringSoon++;
        }
      }
      if (medicine.isLowStock) lowStock.add(medicine);
    }

    return AttentionData(
      expired: expired,
      expiringSoon: expiringSoon,
      lowStock: lowStock,
    );
  }
}
