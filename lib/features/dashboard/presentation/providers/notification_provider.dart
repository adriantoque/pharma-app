import 'package:flutter/material.dart';
import 'notification_model.dart';
import 'notification_repository.dart';

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({required NotificationRepository repository})
      : // A named parameter cannot be private, so `this._repository` is not
        // available and this is the only shape it can take.
        // ignore: prefer_initializing_formals
        _repository = repository {
    // Loads what the repository has. Synchronous, because the repository is
    // in-memory: the list is ready the moment the constructor returns, and
    // the first build of the screen sees it rather than an empty list that
    // fills in a frame later.
    _notifications = _repository.fetchAll();
  }

  final NotificationRepository _repository;
  List<NotificationItem> _notifications = [];

  List<NotificationItem> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void markAsRead(String id) {
    if (_notifications.every((n) => n.id != id || n.isRead)) return;
    _notifications = [
      for (final n in _notifications)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
    notifyListeners();
  }

  void markAllAsRead() {
    if (_notifications.every((n) => n.isRead)) return;
    _notifications = [for (final n in _notifications) n.copyWith(isRead: true)];
    notifyListeners();
  }

  void delete(String id) {
    _notifications = _notifications.where((n) => n.id != id).toList();
    notifyListeners();
  }

  void restore(NotificationItem item) {
    if (_notifications.any((n) => n.id == item.id)) return;
    _notifications = [item, ..._notifications];
    notifyListeners();
  }

  void clearAll() {
    if (_notifications.isEmpty) return;
    _notifications = [];
    notifyListeners();
  }
}

class NotificationFilterProvider extends ChangeNotifier {
  NotificationCategory _selectedCategory = NotificationCategory.all;

  NotificationCategory get selectedCategory => _selectedCategory;

  set selectedCategory(NotificationCategory value) {
    if (_selectedCategory == value) return;
    _selectedCategory = value;
    notifyListeners();
  }
}
