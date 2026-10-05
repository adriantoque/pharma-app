import 'package:flutter/material.dart';

import '../../../../core/utils/currency.dart';
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
      // Format as MM/DD/YYYY for older dates
      return '${time.month}/${time.day}/${time.year}';
    }
  }

  /// Status label for display.
  String get statusLabel => switch (status) {
        OrderStatus.new_ => 'New',
        OrderStatus.approved => 'Approved',
        OrderStatus.rejected => 'Rejected',
      };

  /// Status color for badge.
  Color get statusColor => switch (status) {
        OrderStatus.new_ => const Color(0xFFB7791F), // warn color
        OrderStatus.approved => const Color(0xFF2E7D4F), // ok color
        OrderStatus.rejected => const Color(0xFFB42318), // error color
      };

  /// Background color for status badge.
  Color get statusBackgroundColor => switch (status) {
        OrderStatus.new_ => const Color(0xFFFEF3C7), // warn soft
        OrderStatus.approved => const Color(0xFFD1FAE5), // ok soft
        OrderStatus.rejected => const Color(0xFFFEE4E2), // error soft
      };

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
      'OrderHistory(id: $id, time: $time, status: $status, items: ${items.length}, total: $totalCentavos)';
}

/// Converts between OrderStatus and Firestore string.
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
