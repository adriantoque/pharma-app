import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/medicine_model.dart';
import 'medicine_store.dart';

/// The price list in Firestore, scoped to one signed-in user's account.
///
/// Everything is under `users/{uid}`, so two accounts never see each other's
/// catalogue and the security rules can be as simple as "you may only read and
/// write your own".
class FirestoreMedicineStore implements MedicineStore {
  FirestoreMedicineStore({
    required FirebaseFirestore firestore,
    required String uid,
  })  : _firestore = firestore,
        _collection = firestore
            .collection('users')
            .doc(uid)
            .collection('medicines');

  final FirebaseFirestore _firestore;
  final CollectionReference<Map<String, dynamic>> _collection;

  /// Firestore's own document id, from the write side.
  final Object _serverTimestamp = FieldValue.serverTimestamp();

  @override
  Stream<List<MedicineModel>> watchAll() {
    return _collection
        .orderBy('name')
        .snapshots()
        .map(_toList);
  }

  /// Documents as a sorted, immutable list.
  ///
  /// Ordered here rather than asked of Firestore so the order is the same one
  /// the in-memory list uses. A compound `orderBy` would need a composite index
  /// for every additional sort, and a price list of a few hundred lines is small
  /// enough to order in memory.
  static List<MedicineModel> _toList(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final medicines = [
      for (final document in snapshot.docs)
        MedicineModel.fromFirestore(document.data()),
    ]..sort(MedicineModel.compareByNameThenPrice);
    return List.unmodifiable(medicines);
  }

  @override
  Future<void> setStock(MedicineModel medicine, int? stock) {
    // Only the count. Writing the whole document here would let a count typed
    // on the inventory screen overwrite a price or an expiry that was just
    // corrected, because the widget is holding a copy from before.
    return _collection.doc(medicine.documentId).set(
      {'stock': stock, 'updatedAt': _serverTimestamp},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> setExpiry(MedicineModel medicine, DateTime? expiry) {
    return _collection.doc(medicine.documentId).set(
      {
        'expiryDate': MedicineModel.formatExpiry(expiry),
        'updatedAt': _serverTimestamp,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> upsert(MedicineModel medicine) {
    return _collection
        .doc(medicine.documentId)
        .set({...medicine.toFirestore(), 'updatedAt': _serverTimestamp});
  }

  @override
  Future<void> upsertAll(Iterable<MedicineModel> medicines) async {
    final batch = _firestore.batch();
    var pending = 0;

    for (final medicine in medicines) {
      batch.set(
        _collection.doc(medicine.documentId),
        {...medicine.toFirestore(), 'updatedAt': _serverTimestamp},
      );
      // Firestore caps a batch at 500 writes, and an import is several hundred
      // documents, so this is a limit that is actually reached rather than a
      // theoretical one. Overflow is committed and the batch starts again.
      if (++pending == _batchLimit) {
        await batch.commit();
        pending = 0;
      }
    }

    if (pending > 0) await batch.commit();
  }

  static const int _batchLimit = 500;
}
