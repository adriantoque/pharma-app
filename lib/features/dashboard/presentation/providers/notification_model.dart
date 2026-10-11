import 'package:flutter/material.dart';

enum NotificationCategory { all, stock, orders }

extension NotificationCategoryX on NotificationCategory {
  String get label => switch (this) {
        NotificationCategory.all => 'All',
        NotificationCategory.stock => 'Stock Alerts',
        NotificationCategory.orders => 'Orders',
      };

  IconData get icon => switch (this) {
        NotificationCategory.all => Icons.notifications_outlined,
        NotificationCategory.stock => Icons.inventory_2_outlined,
        NotificationCategory.orders => Icons.receipt_long_outlined,
      };

  Color color(ColorScheme scheme) => switch (this) {
        NotificationCategory.stock => Colors.amber.shade900,
        NotificationCategory.orders => scheme.primary,
        NotificationCategory.all => scheme.secondary,
      };

  String get emptyMessage => switch (this) {
        NotificationCategory.all => 'You are all caught up!',
        NotificationCategory.stock => 'No stock alerts right now.',
        NotificationCategory.orders => 'No order notifications.',
      };

  /// Where a "View details" tap goes when nothing more specific is on the item.
  ///
  /// Null for [NotificationCategory.all], which is a filter over the other
  /// categories rather than one a notification is ever filed under. Every
  /// other category names the screen a user would want next -- the whole
  /// point of a notification is that it is about something somewhere else.
  String? get defaultRoute => switch (this) {
        NotificationCategory.stock => '/inventory',
        NotificationCategory.orders => '/orders',
        NotificationCategory.all => null,
      };
}

@immutable
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationCategory category;
  final bool isRead;

  /// An explicit destination, when one notification has somewhere more
  /// specific to point than the rest of its category. Optional: most
  /// notifications rely on [effectiveRoute]'s category fallback.
  final String? route;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.category,
    this.isRead = false,
    this.route,
  });

  /// Where "View details" should go, or null when there is nowhere useful.
  ///
  /// The explicit [route] wins when a notification has a more specific place
  /// to point; the category's default fills in for the ordinary case. A
  /// notification that can be neither -- a purely informational "the app
  /// updated" style message -- returns null and renders without the button.
  String? get effectiveRoute => route ?? category.defaultRoute;

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    NotificationCategory? category,
    bool? isRead,
    String? route,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      isRead: isRead ?? this.isRead,
      route: route ?? this.route,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationItem && other.id == id && other.isRead == isRead);

  @override
  int get hashCode => Object.hash(id, isRead);
}

/// Formats a timestamp relative to now.
String formatRelativeTime(DateTime timestamp) {
  final diff = DateTime.now().difference(timestamp);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m ${m == 1 ? "minute" : "minutes"} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h ${h == 1 ? "hour" : "hours"} ago';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return '$d ${d == 1 ? "day" : "days"} ago';
  }
  final local = timestamp.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}