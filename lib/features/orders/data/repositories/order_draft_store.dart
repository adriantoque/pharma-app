import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/lifecycle/disposable_store.dart';
import '../models/order_line_model.dart';
import 'order_line_codec.dart';

/// Where the order being built up is kept between runs of the app.
///
/// An interface rather than a Firestore type so the provider can be handed a
/// list in a test: the real one is a single document behind the offline cache,
/// and a test that had to stand up a Firestore to check that an order comes back
/// would cost more than the feature is worth.
///
/// Optional on the provider rather than required. A basket that is thrown away
/// when the app closes is the behaviour the orders tab had before any of this,
/// so a caller with nowhere to keep one -- every test -- keeps that instead of
/// having to pretend otherwise.
abstract interface class OrderDraftStore {
  /// The stored draft, and again whenever it changes.
  ///
  /// Emits an empty list for an account that has never had a draft, so a
  /// subscriber is never left waiting for a first event that may not come.
  Stream<List<OrderLineModel>> watchDraft();

  /// Records [lines] as this device's draft.
  Future<void> save(List<OrderLineModel> lines);

  /// Forgets the draft, which is the same write as saving nothing.
  Future<void> clear();
}

/// The order draft in Firestore, under the signed-in account.
///
/// One document at `users/{uid}/drafts/order`, rather than a collection of
/// orders, because a basket is a single thing: at most a few dozen lines of a
/// catalogue of a few hundred, and a collection would be another round trip per
/// line for no benefit. Firestore paths have to be an even number of segments
/// deep, which is why this is not simply `users/{uid}/order`.
///
/// It leans on the same disk cache as the price list, which is what makes a
/// basket survive the app being killed: the write is applied locally the moment
/// it is made, and Firestore persists it before it goes anywhere near the
/// network.
class FirestoreOrderDraftStore implements OrderDraftStore, DisposableStore {
  FirestoreOrderDraftStore({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _doc = firestore
           .collection('users')
           .doc(uid)
           .collection('drafts')
           .doc('order');

  final DocumentReference<Map<String, dynamic>> _doc;

  /// The revision this device has last written or accepted.
  ///
  /// The document carries a number as well as the lines because "the snapshot
  /// that arrived is older than the edit I just made" is the one race that
  /// matters here, and content comparison alone cannot tell it from a genuine
  /// change made elsewhere: restoring a draft produces lines nobody in this
  /// process has written.
  int _revision = 0;

  /// Exactly what was last sent, so the echo of this device's own write is not
  /// read back as somebody else's change.
  List<OrderLineModel>? _lastWritten;

  bool _disposed = false;

  @override
  Stream<List<OrderLineModel>> watchDraft() {
    return _doc.snapshots().transform(
      StreamTransformer<
        DocumentSnapshot<Map<String, dynamic>>,
        List<OrderLineModel>
      >.fromHandlers(
        handleData: (snapshot, sink) {
          final lines = _accept(snapshot);
          if (lines != null) sink.add(lines);
        },
      ),
    );
  }

  /// What to show for [snapshot], or null for one that must not be acted on.
  ///
  /// Three outcomes, and the middle one is the whole reason this method exists:
  /// this device's own write coming back (ignore it, it is already on screen),
  /// something newer from elsewhere (take it), and something older that arrived
  /// late (ignore it, or a basket typed a moment ago would be wiped by the cached
  /// draft that was already in hand when it was typed).
  List<OrderLineModel>? _accept(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (_disposed) return null;

    final data = snapshot.data();
    if (data == null) return const <OrderLineModel>[];

    final revision = OrderLineCodec.readIntOrNull(data['revision']) ?? 0;
    final lines = OrderLineCodec.readList(data['lines']);

    final written = _lastWritten;
    if (written != null && _sameLines(written, lines)) return null;
    if (revision <= _revision) return null;

    _revision = revision;
    return lines;
  }

  @override
  Future<void> save(List<OrderLineModel> lines) async {
    // Set before the write goes out rather than after it lands, so a snapshot
    // arriving in the gap is compared against what was just sent rather than
    // against whatever the previous save was.
    _lastWritten = List<OrderLineModel>.unmodifiable(lines);
    _revision++;
    final revision = _revision;

    await _doc.set({
      'lines': OrderLineCodec.listToMaps(lines),
      'revision': revision,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> clear() => save(const <OrderLineModel>[]);

  /// Compared by line identity and amount, which is all that is stored.
  static bool _sameLines(List<OrderLineModel> a, List<OrderLineModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].quantity != b[i].quantity || a[i].medicine != b[i].medicine) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
  }
}
