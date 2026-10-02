import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/lifecycle/disposable_store.dart';
import '../models/order_line_model.dart';
import 'order_draft_store.dart';
import 'order_line_codec.dart';

/// A draft basket that is stored on this device, for offline mode.
///
/// The shape is identical to the Firestore draft so the provider cannot tell
/// which backing store it is reading from: a revisioned list of order lines
/// encoded by [OrderLineCodec]. Everything is best-effort -- a corrupted JSON
/// string is treated as an empty basket rather than crashing.
class LocalOrderDraftStore implements OrderDraftStore, DisposableStore {
  LocalOrderDraftStore({Future<SharedPreferences>? prefs})
    : _prefsFuture = prefs ?? SharedPreferences.getInstance();

  static const String _key = 'offlineOrderDraft';

  final Future<SharedPreferences> _prefsFuture;
  final StreamController<List<OrderLineModel>> _controller =
      StreamController<List<OrderLineModel>>.broadcast();

  bool _disposed = false;

  @override
  Stream<List<OrderLineModel>> watchDraft() async* {
    yield await _read();
    yield* _controller.stream;
  }

  Future<List<OrderLineModel>> _read() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_key);
    if (raw == null) return const <OrderLineModel>[];
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return OrderLineCodec.readList(decoded['lines']);
    } catch (_) {
      return const <OrderLineModel>[];
    }
  }

  @override
  Future<void> save(List<OrderLineModel> lines) async {
    final prefs = await _prefsFuture;
    try {
      final data = <String, dynamic>{
        'lines': OrderLineCodec.listToMaps(lines),
        'revision': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_key, jsonEncode(data));
    } catch (_) {
      // Ignored: persistence is best-effort and the in-memory basket is fine
      // for the current session.
    }
    if (!_controller.isClosed) {
      _controller.add(List<OrderLineModel>.unmodifiable(lines));
    }
  }

  @override
  Future<void> clear() => save(const <OrderLineModel>[]);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_controller.close());
  }
}
