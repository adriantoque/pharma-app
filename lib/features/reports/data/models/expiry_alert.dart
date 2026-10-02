/// Expiring item alert for the "Expiring" tab.
class ExpiryAlert {
  const ExpiryAlert({
    required this.name,
    required this.expiryDate,
    required this.quantity,
    this.category,
  });

  final String name;
  final DateTime expiryDate;
  final int quantity;
  final String? category;

  /// Days until expiry (negative if already expired).
  int get daysUntilExpiry {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }

  /// Whether the item is already expired.
  bool get isExpired => daysUntilExpiry < 0;

  /// Whether the item expires within 30 days (warning zone).
  bool get isWarning => daysUntilExpiry >= 0 && daysUntilExpiry <= 30;

  /// Whether the item expires within 45 days (urgent).
  bool get isUrgent => daysUntilExpiry >= 0 && daysUntilExpiry <= 45;

  /// Color-coded severity for UI.
  ExpirySeverity get severity {
    if (isExpired) return ExpirySeverity.expired;
    if (daysUntilExpiry <= 30) return ExpirySeverity.critical;
    if (daysUntilExpiry <= 45) return ExpirySeverity.warning;
    return ExpirySeverity.ok;
  }

  String get formattedExpiryDate {
    return '${expiryDate.day} ${_monthShort(expiryDate.month)} ${expiryDate.year}';
  }

  String get formattedDaysRemaining {
    final days = daysUntilExpiry;
    if (days < 0) return '${(-days)} days ago';
    if (days == 0) return 'Today';
    return '$days days';
  }

  static String _monthShort(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

/// Severity levels for expiry items.
enum ExpirySeverity {
  /// Already expired - red badge.
  expired,

  /// Expires within 30 days - red badge.
  critical,

  /// Expires within 45 days - amber/warning badge.
  warning,

  /// Expires after 45 days - neutral.
  ok,
}
