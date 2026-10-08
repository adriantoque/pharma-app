import 'notification_model.dart';

abstract class NotificationRepository {
  List<NotificationItem> fetchAll();
}

class InMemoryNotificationRepository implements NotificationRepository {
  @override
  List<NotificationItem> fetchAll() {
    final now = DateTime.now();
    return [
      NotificationItem(
        id: '1',
        title: 'Out of Stock Alert',
        message: 'Paracetamol 500mg is completely out of stock.',
        timestamp: now.subtract(const Duration(minutes: 15)),
        category: NotificationCategory.stock,
        // No explicit route: falls through to /inventory via the category
        // default.
      ),
      NotificationItem(
        id: '2',
        title: 'New Order Received',
        message: 'Order #1728139200 requires cashier approval.',
        timestamp: now.subtract(const Duration(hours: 1)),
        category: NotificationCategory.orders,
        // No explicit route: falls through to /orders.
      ),
      NotificationItem(
        id: '3',
        title: 'Expiring Medicine Warning',
        message: 'Mefenamic Acid 500mg expires in 5 days.',
        timestamp: now.subtract(const Duration(hours: 3)),
        category: NotificationCategory.expiry,
        isRead: true,
        // No explicit route: falls through to /home/expiring.
      ),
      NotificationItem(
        id: '4',
        title: 'Low Stock Threshold',
        message: 'Amoxicillin 500mg has 2 units remaining (Threshold: 10).',
        timestamp: now.subtract(const Duration(days: 1)),
        category: NotificationCategory.stock,
        isRead: true,
        // No explicit route: falls through to /inventory.
      ),
    ];
  }
}