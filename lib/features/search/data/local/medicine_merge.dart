/// The server's answer laid over the local rows.
///
/// One merge shared by the mirroring in [SyncedMedicineStore] and by the
/// emission it shows the user, so what the pharmacist sees is exactly what was
/// written into the cache.
///
/// The rules, in the order they are applied:
///
/// 1. A document whose id is in [preferBaseIds] is left as the local row. Those
///    are edits this device made that the server has not acknowledged -- a
///    stale snapshot must not overwrite them. With medicine writes local-only
///    nothing is queued to the server any more, so in practice this set is
///    empty; it stays as the belt over the braces in rule 2.
/// 2. A server line the local rows also know (same document id) supplies the
///    catalogue fields, because the server is the source of truth for names,
///    prices and descriptions -- but the shelf fields it does not own are the
///    local copy's. Medicine writes never reach the server, so `stock` and
///    `expiryDate` are local facts: a snapshot must not undo a count typed
///    here, and a local value is preferred wherever the cache holds one. The
///    descriptive fields -- the usage indication and the per-age annotations --
///    were added to the catalogue after older collections were seeded, so a
///    server line that predates them must not blank one out either.
/// 3. A server line without a product id is matched by legacy identity -- the
///    exact name and price, the identity the price list used before product ids
///    existed. `Amox` at 4.00 is not `Amox` at 45.00. The same shelf-field rule
///    applies: the local count and date win, the server's fill a gap.
///    Legacy matching needs a base that has product ids to compare against: a
///    whole-legacy cache matches by document id directly, because both sides
///    were hashed from the same identity.
/// 4. A server line nothing matches is added whole: a medicine an admin added
///    by hand must reach the cache and every client, not be dropped.
/// 5. A local line the server does not know is kept. It may be a line this
///    device created, or the server may simply not have been seeded with it;
///    in both cases it is a real line on this pharmacy's shelf.
library;

import '../models/age_guidance.dart';
import '../models/medicine_model.dart';

/// The merged catalogue, sorted the way the price list is shown.
List<MedicineModel> mergeMedicines({
  required List<MedicineModel> base,
  required List<MedicineModel> remote,
  Set<String> preferBaseIds = const {},
}) {
  if (remote.isEmpty) return List.unmodifiable(base);
  if (base.isEmpty) return List.unmodifiable(remote);

  final baseProductIds = {
    for (final medicine in base)
      if (medicine.productId != null) medicine.productId!,
  };
  final legacyMatches = <String, MedicineModel>{};
  final ambiguousLegacyKeys = <String>{};
  if (baseProductIds.isNotEmpty) {
    for (final medicine in base) {
      final key = legacyIdentity(medicine);
      if (legacyMatches.containsKey(key)) {
        legacyMatches.remove(key);
        ambiguousLegacyKeys.add(key);
      } else if (!ambiguousLegacyKeys.contains(key)) {
        legacyMatches[key] = medicine;
      }
    }
  }

  final byId = <String, MedicineModel>{
    for (final medicine in base) medicine.documentId: medicine,
  };
  for (final medicine in remote) {
    if (preferBaseIds.contains(medicine.documentId)) continue;

    if (baseProductIds.isNotEmpty) {
      if (medicine.productId != null) {
        final existing = byId[medicine.documentId];
        if (existing != null) {
          byId[medicine.documentId] = medicine.copyWith(
            usageIndication:
                medicine.usageIndication ?? existing.usageIndication,
            ageGuidance: medicine.ageGuidance ?? existing.ageGuidance,
            // A missing rating reads as `both` on the way in, so a server line
            // recorded before the age columns existed says `both` when what
            // the cache holds is a real answer.
            ageGroup: medicine.ageGroup == AgeGroup.both &&
                    existing.ageGroup != AgeGroup.both
                ? existing.ageGroup
                : medicine.ageGroup,
            // The shelf fields are local facts: writes never reach the server,
            // so a snapshot must not undo a count or a date typed here. A null
            // local value is "uncounted", not "cleared against the server", so
            // the server's fill a gap -- and a fresh device still inherits the
            // counts the import carried.
            stock: existing.stock ?? medicine.stock,
            expiryDate: existing.expiryDate ?? medicine.expiryDate,
          );
        } else {
          byId[medicine.documentId] = medicine;
        }
        continue;
      }

      final legacy = legacyMatches[legacyIdentity(medicine)];
      if (legacy != null) {
        if (preferBaseIds.contains(legacy.documentId)) continue;
        byId[legacy.documentId] = legacy.copyWith(
          stock: legacy.stock ?? medicine.stock,
          expiryDate: legacy.expiryDate ?? medicine.expiryDate,
          aliases:
              medicine.aliases.isEmpty ? legacy.aliases : medicine.aliases,
          genericKey: medicine.genericKey ?? legacy.genericKey,
        );
      } else {
        byId[medicine.documentId] = medicine;
      }
      continue;
    }
    byId[medicine.documentId] = medicine;
  }

  final merged = byId.values.toList()
    ..sort(MedicineModel.compareByNameThenPrice);
  return List.unmodifiable(merged);
}

/// The identity a line without a product id is matched by.
///
/// Kept in one place here rather than inlined so a merge bug cannot hide
/// between two copies of the rule.
String legacyIdentity(MedicineModel medicine) =>
    '${medicine.name}\u0000${medicine.priceCentavos}';
