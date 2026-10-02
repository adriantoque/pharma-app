import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/lifecycle/disposable_store.dart';
import '../models/order_history_model.dart';
import 'order_history_repository.dart';
import 'order_line_codec.dart';

/// Firestore implementation of [OrderHistoryRepository].
///
/// Stores orders in a subcollection `orders` under the user's document:
/// `users/{uid}/orders/{orderId}`
class FirestoreOrderHistoryRepository
    implements OrderHistoryRepository, DisposableStore {
  FirestoreOrderHistoryRepository({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _collection = firestore
           .collection('users')
           .doc(uid)
           .collection('orders');

  final CollectionReference<Map<String, dynamic>> _collection;

  @override
  Stream<List<OrderHistory>> watchAll() {
    return _collection.orderBy('time', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => _fromFirestore(doc)).toList();
    });
  }

  @override
  Future<void> save(OrderHistory order) async {
    await _collection.doc(order.id).set({
      'time': Timestamp.fromDate(order.time),
      'status': OrderStatusCodec.statusToString(order.status),
      'lines': OrderLineCodec.listToMaps(order.items),
      'totalCentavos': order.totalCentavos,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateStatus(String id, OrderStatus status) async {
    await _collection.doc(id).update({
      'status': OrderStatusCodec.statusToString(status),
    });
  }

  @override
  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }

  OrderHistory _fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final lines = OrderLineCodec.readList(data['lines']);
    final time = (data['time'] as Timestamp?)?.toDate() ?? DateTime.now();
    final status = OrderStatusCodec.statusFromString(
      data['status'] as String? ?? 'new',
    );
    final totalCentavos = data['totalCentavos'] as int? ?? 0;

    return OrderHistory(
      id: doc.id,
      time: time,
      status: status,
      items: lines,
      totalCentavos: totalCentavos,
    );
  }

  @override
  void dispose() {
    // No streams to close for this implementation
  }
}
