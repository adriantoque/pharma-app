// Converts between a [MedicineRow] and a [MedicineModel].
//
// One direction goes through [MedicineModel.fromFirestore] on purpose. The
// lenient parser that reads Firestore documents is exactly the parser a row
// read back out of SQLite needs -- a stock that fails to parse becomes
// uncounted, an expiry in an odd shape becomes no expiry -- and a second
// parser here would be a second place for that rule to drift.
library;

import 'dart:convert';

import '../models/age_guidance.dart';
import '../models/medicine_model.dart';
import 'app_database.dart';

/// The model a row stands for.
MedicineModel medicineFromRow(MedicineRow row) {
  return MedicineModel.fromFirestore({
    'name': row.name,
    'productId': row.productId,
    'packageType': row.packageType,
    'usageIndication': row.usageIndication,
    'priceCentavos': row.priceCentavos,
    'stock': row.stock,
    'aliases': _decodeAliases(row.aliases),
    'genericKey': row.genericKey,
    'expiryDate': row.expiryDate,
    'requiresRx': row.requiresRx,
    'category': row.category,
    'dosageInfo': row.dosageInfo,
    'cautions': row.cautions,
    'ageGroup': row.ageGroup,
    'ageGuidance': _decodeJson(row.ageGuidance),
  });
}

/// The row a model stands for, keyed by its [MedicineModel.documentId].
MedicineRow rowFromMedicine(MedicineModel medicine, {int? updatedAt}) {
  return MedicineRow(
    id: medicine.documentId,
    name: medicine.name,
    productId: medicine.productId,
    packageType: medicine.packageType,
    usageIndication: medicine.usageIndication,
    priceCentavos: medicine.priceCentavos,
    stock: medicine.stock,
    aliases: jsonEncode(medicine.aliases),
    genericKey: medicine.genericKey,
    expiryDate: MedicineModel.formatExpiry(medicine.expiryDate),
    requiresRx: medicine.requiresRx,
    category: medicine.category,
    dosageInfo: medicine.dosageInfo,
    cautions: medicine.cautions,
    ageGroup: medicine.ageGroup.name,
    ageGuidance: _encodeGuidance(medicine.ageGuidance),
    updatedAt: updatedAt,
  );
}

/// Every model field as it is stored, for change detection without a second
/// notion of equality. [MedicineModel.operator ==] is identity-only (name,
/// price, package), which is right for lookups and wrong for asking whether a
/// mirror write would change anything.
Map<String, dynamic> medicineFingerprint(MedicineModel medicine) {
  return medicine.toFirestore()..remove('updatedAt');
}

/// Whether [a] and [b] are the same line with the same stored values.
bool sameStoredMedicine(MedicineModel? a, MedicineModel? b) {
  if (a == null || b == null) return a == null && b == null;
  if (a.documentId != b.documentId) return false;
  return const _MapEquality().equals(
    medicineFingerprint(a),
    medicineFingerprint(b),
  );
}

String? _encodeGuidance(AgeGuidance? guidance) =>
    guidance == null ? null : jsonEncode(guidance.toMap());

List<String> _decodeAliases(String stored) {
  return switch (_decodeJson(stored)) {
    final List entries => [
      for (final entry in entries)
        if (entry is String && entry.isNotEmpty) entry,
    ],
    _ => const [],
  };
}

Object? _decodeJson(String? stored) {
  if (stored == null || stored.isEmpty) return null;
  try {
    return jsonDecode(stored);
  } catch (_) {
    // A payload that will not decode is a field the app cannot read, not a row
    // it should drop: the honest reading is the same one
    // [MedicineModel.fromFirestore] gives an unreadable Firestore field.
    return null;
  }
}

/// A field-by-field map comparison, because `Map.==` is identity.
class _MapEquality {
  const _MapEquality();

  bool equals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!_sameValue(b[entry.key], entry.value)) return false;
    }
    return true;
  }

  bool _sameValue(Object? a, Object? b) {
    if (a is List && b is List) {
      return a.length == b.length && a.every((v) => b.contains(v));
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final entry in a.entries) {
        if (!_sameValue(b[entry.key], entry.value)) return false;
      }
      return true;
    }
    return a == b;
  }
}
