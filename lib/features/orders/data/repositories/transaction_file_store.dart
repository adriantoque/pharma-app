import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/lifecycle/disposable_store.dart';
import '../models/order_history_model.dart';
import 'order_history_repository.dart';
import 'order_line_codec.dart';

/// A local transaction ledger that survives restarts and network state.
///
/// Every order that reaches [OrderStatus.approved] is written here as well as
/// to whichever repository the current session uses (Firestore for online,
/// in-memory for offline). The file is the durable record: it is read on every
/// startup so the Order History screen always has something to show, and it is
/// the source that uploads to the signed-in account when the device comes back
/// online.
///
/// The stored shape is the same Firestore document shape that
/// [FirestoreOrderHistoryRepository.save] writes, so a transaction file entry
/// can be replayed into Firestore without a separate conversion.
class TransactionFileStore implements OrderHistoryRepository, DisposableStore {
  TransactionFileStore({Future<SharedPreferences>? prefs})
      : _prefsFuture = prefs ?? SharedPreferences.getInstance();

  static const String _key = 'transactionHistory';

  final Future<SharedPreferences> _prefsFuture;
  final StreamController<List<OrderHistory>> _controller =
      StreamController<List<OrderHistory>>.broadcast();

  bool _disposed = false;

  @override
  Stream<List<OrderHistory>> watchAll() async* {
    yield await _read();
    yield* _controller.stream;
  }

  /// All approved transactions currently on file, newest first.
  Future<List<OrderHistory>> _read() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const <OrderHistory>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final orders = <OrderHistory>[];
      for (final entry in decoded) {
        final order = _fromMap(entry);
        if (order != null) orders.add(order);
      }
      orders.sort((a, b) => b.time.compareTo(a.time));
      return orders;
    } catch (_) {
      return const <OrderHistory>[];
    }
  }

  OrderHistory? _fromMap(dynamic entry) {
    if (entry is! Map) return null;
    final data = entry as Map<String, dynamic>;
    final lines = OrderLineCodec.readList(data['lines']);
    if (lines.isEmpty) return null;
    final time = _readTime(data['time']);
    final status = OrderStatusCodec.statusFromString(
      data['status'] as String? ?? 'new',
    );
    final totalCentavos = OrderLineCodec.readIntOrNull(data['totalCentavos']) ?? 0;
    final id = data['id'];
    if (id is! String || id.isEmpty) return null;
    return OrderHistory(
      id: id,
      time: time,
      status: status,
      items: lines,
      totalCentavos: totalCentavos,
      rejectionReason: data['rejectionReason'] as String?,
    );
  }

  DateTime _readTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  /// Appends an approved order to the transaction file.
  @override
  Future<void> save(OrderHistory order) async {
    if (order.status != OrderStatus.approved) return;

    final prefs = await _prefsFuture;
    try {
      final existing = await _read();
      final updated = [...existing, order];
      await prefs.setString(_key, jsonEncode([for (final o in updated) _toMap(o)]));
    } catch (_) {
      // Best-effort: the order still exists in the session repository.
    }
    if (!_controller.isClosed) {
      _controller.add(await _read());
    }
  }

  Map<String, dynamic> _toMap(OrderHistory order) => {
        'id': order.id,
        'time': order.time.millisecondsSinceEpoch,
        'status': OrderStatusCodec.statusToString(order.status),
        'lines': OrderLineCodec.listToMaps(order.items),
        'totalCentavos': order.totalCentavos,
        'rejectionReason': order.rejectionReason,
        'createdAt': null,
      };

  @override
  Future<void> updateStatus(
    String id,
    OrderStatus status, {
    String? rejectionReason,
  }) async {
    if (status != OrderStatus.approved) return;
    final orders = await _read();
    final index = orders.indexWhere((o) => o.id == id);
    if (index == -1) return;
    // Only approved orders ever reach this store, so a rejection reason is
    // always null here. It is threaded through anyway so the stored shape stays
    // the same as a Firestore order document.
    final updated = orders[index].copyWith(
      status: status,
      rejectionReason: rejectionReason,
    );
    orders[index] = updated;
    final prefs = await _prefsFuture;
    try {
      await prefs.setString(
        _key,
        jsonEncode([for (final o in orders) _toMap(o)]),
      );
    } catch (_) {}
    if (!_controller.isClosed) {
      _controller.add(await _read());
    }
  }

  @override
  Future<void> delete(String id) async {
    final orders = await _read();
    orders.removeWhere((o) => o.id == id);
    final prefs = await _prefsFuture;
    try {
      await prefs.setString(
        _key,
        jsonEncode([for (final o in orders) _toMap(o)]),
      );
    } catch (_) {}
    if (!_controller.isClosed) {
      _controller.add(await _read());
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_controller.close());
  }
}
