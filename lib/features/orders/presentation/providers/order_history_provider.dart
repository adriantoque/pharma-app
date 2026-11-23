import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/order_history_model.dart';
import '../../data/repositories/order_history_repository.dart';

/// Which slice of history the screen is showing.
enum HistoryFilter {
  all('All'),
  approved('Approved'),
  rejected('Rejected');

  const HistoryFilter(this.label);

  final String label;

  bool accepts(OrderStatus status) => switch (this) {
        HistoryFilter.all => true,
        HistoryFilter.approved => status == OrderStatus.approved,
        HistoryFilter.rejected => status == OrderStatus.rejected,
      };
}

/// The state of the Order History screen: what the search box says, which
/// filter chip is selected, and the orders those two things leave visible.
///
/// Owns its own subscription to the history stream so the screen can rebuild
/// on any change without holding the repository itself. The screen is the only
/// consumer, which is why this is scoped to the screen rather than registered
/// above the router.
class OrderHistoryProvider extends ChangeNotifier {
  OrderHistoryProvider({required OrderHistoryRepository repository})
      // A named parameter cannot be private, so `this._repository` is not
      // available and this is the only shape it can take.
      // ignore: prefer_initializing_formals
      : _repository = repository {
    _subscription = _repository.watchAll().listen(
      (orders) {
        _all = orders;
        _error = null;
        _safeNotify();
      },
      onError: (Object error) {
        _error = error.toString();
        _safeNotify();
      },
    );
  }

  final OrderHistoryRepository _repository;
  StreamSubscription<List<OrderHistory>>? _subscription;

  List<OrderHistory> _all = const [];
  String _query = '';
  HistoryFilter _filter = HistoryFilter.all;
  String? _error;
  bool _disposed = false;

  String get query => _query;
  HistoryFilter get filter => _filter;
  String? get error => _error;

  /// True only before the first emission. An empty history that has been read
  /// is not loading -- it is empty, and the screen says so.
  bool get isLoading => _all.isEmpty && _error == null && _firstEmission == false;
  bool _firstEmission = false;

  /// The orders the current query and filter leave visible, newest first.
  ///
  /// The repository already sorts by time descending; this re-sorts after
  /// filtering because a search can change nothing about the order and the
  /// list should keep reading newest-first either way.
  List<OrderHistory> get results {
    final filtered = _all
        .where((o) => _filter.accepts(o.status))
        .where((o) => o.matches(_query))
        .toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    return List.unmodifiable(filtered);
  }

  /// Total orders on file, ignoring the filter and query.
  int get totalCount => _all.length;

  /// How many of each state, for the chip labels.
  Map<HistoryFilter, int> get counts => {
        HistoryFilter.all: _all.length,
        HistoryFilter.approved:
            _all.where((o) => o.status == OrderStatus.approved).length,
        HistoryFilter.rejected:
            _all.where((o) => o.status == OrderStatus.rejected).length,
      };

  void updateQuery(String value) {
    if (_query == value) return;
    _query = value;
    _safeNotify();
  }

  void setFilter(HistoryFilter value) {
    if (_filter == value) return;
    _filter = value;
    _safeNotify();
  }

  void clearQuery() => updateQuery('');

  void _safeNotify() {
    if (_disposed) return;
    _firstEmission = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
