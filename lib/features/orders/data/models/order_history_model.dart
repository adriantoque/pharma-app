import 'package:flutter/material.dart';

import '../../../../core/utils/currency.dart';
import '../../../../core/utils/search_text.dart';
import '../models/order_line_model.dart';

/// Status of an order in history.
enum OrderStatus {
  /// Order is new and awaiting approval.
  new_,

  /// Order has been approved.
  approved,

  /// Order has been rejected, and is no longer actionable.
  rejected,
}

/// A completed order stored in history.
///
/// Immutable, so it can be safely shared and compared.
class OrderHistory {
  const OrderHistory({
    required this.id,
    required this.time,
    required this.status,
    required this.items,
    required this.totalCentavos,
  });

  /// Unique identifier for the order.
  final String id;

  /// When the order was placed.
  final DateTime time;

  /// Current status of the order.
  final OrderStatus status;

  /// Items in the order.
  final List<OrderLineModel> items;

  /// Total in centavos.
  final int totalCentavos;

  /// Total formatted as currency string.
  String get formattedTotal => formatCentavos(totalCentavos);

  /// Human-readable relative time (e.g., "5 min ago", "Yesterday").
  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hr ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return formattedDate(context: null);
    }
  }

  /// The order's date and time, in the platform's own medium format.
  ///
  /// Takes the [BuildContext] rather than reading from it directly so the
  /// method can be called from a widget without the caller having to pass the
  /// context through a getter chain. Falls back to a hand-rolled `MMM d, yyyy`
  /// when [context] is null, which is only used by [relativeTime] for logs and
  /// tests where there is no localisation to consult.
  String formattedDate({BuildContext? context}) {
    if (context != null) {
      final localizations = MaterialLocalizations.of(context);
      final date = localizations.formatMediumDate(time);
      final clock = localizations.formatTimeOfDay(
        TimeOfDay.fromDateTime(time),
      );
      return '$date · $clock';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '${months[time.month - 1]} ${time.day}, ${time.year} · '
        '$hour12:$minute $period';
  }

  /// Status label for display.
  String get statusLabel => switch (status) {
        OrderStatus.new_ => 'New',
        OrderStatus.approved => 'Approved',
        OrderStatus.rejected => 'Rejected',
      };

  /// Status color for badge.
  Color get statusColor => switch (status) {
        OrderStatus.new_ => const Color(0xFFB7791F),
        OrderStatus.approved => const Color(0xFF2E7D4F),
        OrderStatus.rejected => const Color(0xFFB42318),
      };

  /// Background color for status badge.
  Color get statusBackgroundColor => switch (status) {
        OrderStatus.new_ => const Color(0xFFFEF3C7),
        OrderStatus.approved => const Color(0xFFD1FAE5),
        OrderStatus.rejected => const Color(0xFFFEE4E2),
      };

  /// Whether this order should appear for [query].
  ///
  /// Searches the id, the status, the date and every medicine name in the
  /// order so one field can find an order by any of the things somebody would
  /// remember about it. An empty query matches everything -- the unfiltered
  /// list and the filtered list are the same code path.
  bool matches(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return true;
    final needle = normaliseForSearch(trimmed);

    if (normaliseForSearch(id).contains(needle)) return true;
    if (normaliseForSearch(statusLabel).contains(needle)) return true;
    if (normaliseForSearch(_dateHaystack).contains(needle)) return true;

    for (final line in items) {
      if (normaliseForSearch(line.medicine.name).contains(needle)) {
        return true;
      }
    }
    return false;
  }

  /// The date rendered in a form a search can hit: `2026-10-08`, `oct 8`,
  /// `october 8`. Assembled from the parts rather than from a locale format,
  /// because a search should not depend on the phone's language.
  String get _dateHaystack {
    const months = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
    ];
    final monthName = months[time.month - 1];
    final shortMonth = monthName.substring(0, 3);
    final iso = '${time.year}-'
        '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')}';
    return '$iso $monthName $shortMonth ${time.day} ${time.year}';
  }

  /// Creates a copy with some fields replaced.
  OrderHistory copyWith({
    String? id,
    DateTime? time,
    OrderStatus? status,
    List<OrderLineModel>? items,
    int? totalCentavos,
  }) {
    return OrderHistory(
      id: id ?? this.id,
      time: time ?? this.time,
      status: status ?? this.status,
      items: items ?? this.items,
      totalCentavos: totalCentavos ?? this.totalCentavos,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderHistory &&
          other.id == id &&
          other.time == time &&
          other.status == status &&
          other.items == items &&
          other.totalCentavos == totalCentavos;

  @override
  int get hashCode => Object.hash(id, time, status, items, totalCentavos);

  @override
  String toString() =>
      'OrderHistory(id: $id, time: $time, status: $status, '
      'items: ${items.length}, total: $totalCentavos)';
}

/// Converts between [OrderStatus] and the string stored in Firestore.
class OrderStatusCodec {
  static const Map<OrderStatus, String> _toString = {
    OrderStatus.new_: 'new',
    OrderStatus.approved: 'approved',
    OrderStatus.rejected: 'rejected',
  };

  static const Map<String, OrderStatus> _fromString = {
    'new': OrderStatus.new_,
    'approved': OrderStatus.approved,
    'rejected': OrderStatus.rejected,
  };

  static String statusToString(OrderStatus status) => _toString[status]!;

  static OrderStatus statusFromString(String string) =>
      _fromString[string] ?? OrderStatus.new_;
}