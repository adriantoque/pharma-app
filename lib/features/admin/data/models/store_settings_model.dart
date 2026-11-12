/// The pharmacy's own settings: the things an admin sets once and the rest of
/// the app reads.
///
/// One document (`settings/store`), not a collection, because there is exactly
/// one store per app install and a collection would only invite "which id is
/// the live one?" bugs. Everything here is optional to *fill in* but required
/// to *exist* -- the model's defaults mean a pharmacy that never opens this
/// screen still gets sensible rules (5 items, 30 days) rather than nulls the
/// readers would each have to guess around.
///
/// Plain Dart on purpose: no Flutter import, so the model is testable and
/// reusable from any layer, the same contract the other `data/models` carry.
///
/// Money does not appear here. Prices are a property of the price list, not of
/// the store.
class StoreSettingsModel {
  const StoreSettingsModel({
    this.name = '',
    this.address,
    this.phone,
    this.openMinutes = defaultOpenMinutes,
    this.closeMinutes = defaultCloseMinutes,
    this.lowStockThreshold = defaultLowStockThreshold,
    this.expiryWarningDays = defaultExpiryWarningDays,
    this.reorderCoverageDays = defaultReorderCoverageDays,
    this.updatedBy,
    this.updatedAt,
  });

  /// Reads a Firestore document. Tolerant of missing and mistyped fields the
  /// way the other models are: a document written before a field existed, or
  /// by a hand edit in the console, still loads.
  factory StoreSettingsModel.fromMap(Map<String, dynamic> data) {
    return StoreSettingsModel(
      name: data['name'] as String? ?? '',
      address: data['address'] as String?,
      phone: data['phone'] as String?,
      openMinutes: _readMinutes(data['openMinutes'], defaultOpenMinutes),
      closeMinutes: _readMinutes(data['closeMinutes'], defaultCloseMinutes),
      lowStockThreshold:
          data['lowStockThreshold'] is int
              ? data['lowStockThreshold'] as int
              : defaultLowStockThreshold,
      expiryWarningDays:
          data['expiryWarningDays'] is int
              ? data['expiryWarningDays'] as int
              : defaultExpiryWarningDays,
      reorderCoverageDays:
          data['reorderCoverageDays'] is int
              ? data['reorderCoverageDays'] as int
              : defaultReorderCoverageDays,
      updatedBy: data['updatedBy'] as String?,
      updatedAt: (data['updatedAt'] as dynamic)?.toDate() as DateTime?,
    );
  }

  /// A document that has never been saved still has to show something.
  static const int defaultLowStockThreshold = 5;

  /// A standard pharmacy day: 8 in the morning to 5 in the afternoon.
  static const int defaultOpenMinutes = 8 * 60;
  static const int defaultCloseMinutes = 17 * 60;

  /// The choices offered for the expiry warning window. A fixed list rather
  /// than free entry because the window drives a list anyone can read -- a
  /// threshold of 47 days would be a setting nobody could act on.
  static const List<int> expiryWindowChoices = [30, 60, 90];

  /// Ninety days, matching what the Expiring Meds screen showed before this
  /// became a setting: a setting's default is the behaviour the app already
  /// had, so opening the settings screen and saving nothing changes nothing.
  static const int defaultExpiryWarningDays = 90;

  /// The choices for how many days of demand a reorder should cover. A fixed
  /// list like [expiryWindowChoices]: the window sizes the reorder targets the
  /// whole app reads, and a 47-day coverage is a number nobody could check.
  static const List<int> reorderCoverageChoices = [7, 14, 30];

  /// Two weeks of stock. Long enough to ride out a supplier's lead time on
  /// the fast movers, short enough that the targets stay honest to recent
  /// demand rather than stocking the shelf a month deep.
  static const int defaultReorderCoverageDays = 14;

  static const int minLowStockThreshold = 1;
  static const int maxLowStockThreshold = 99;

  /// The store's name as it should read on reports and exports. Blank until
  /// the admin fills it in; the settings screen shows "Not set yet".
  final String name;

  /// Where the pharmacy is, if anyone bothered to record it. Nullable: the
  /// catalogue imports carry no address, and an empty string would read as
  /// "typed and cleared" rather than "never asked".
  final String? address;
  final String? phone;

  /// Opening and closing time, as minutes from midnight. Ints rather than a
  /// time-of-day type because the model stays Flutter-free; the screen owns
  /// the widget conversion.
  final int openMinutes;
  final int closeMinutes;

  /// At or below this shelf count, a line is called out as low. Drives the
  /// search rows, the dashboard tile and the low-stock report through
  /// `MedicineModel.lowStockThreshold`.
  final int lowStockThreshold;

  /// How far ahead a shelf expiry is worth warning about, in days.
  final int expiryWarningDays;

  /// How many days of demand a reorder target should cover, in days. The
  /// deficit on the low-stock lists is measured against this: enough stock to
  /// cover the window at the observed selling rate, floored at
  /// [lowStockThreshold].
  final int reorderCoverageDays;

  /// Who saved the settings last, and when. Display-only: shown in the
  /// settings footer so the admin can see the change landed. The audit log is
  /// the real record.
  final String? updatedBy;
  final DateTime? updatedAt;

  /// Everything an admin can edit, and nothing they cannot. `updatedAt` and
  /// `updatedBy` are bookkeeping, not settings, so equality ignores them --
  /// otherwise a save that changed nothing would still read as dirty, because
  /// the server stamped a fresh time.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoreSettingsModel &&
        other.name == name &&
        other.address == address &&
        other.phone == phone &&
        other.openMinutes == openMinutes &&
        other.closeMinutes == closeMinutes &&
        other.lowStockThreshold == lowStockThreshold &&
        other.expiryWarningDays == expiryWarningDays &&
        other.reorderCoverageDays == reorderCoverageDays;
  }

  @override
  int get hashCode => Object.hash(
        name,
        address,
        phone,
        openMinutes,
        closeMinutes,
        lowStockThreshold,
        expiryWarningDays,
        reorderCoverageDays,
      );

  /// Every rule this document breaks, one human-readable line each. Empty
  /// means the settings are safe to write.
  ///
  /// On the model rather than in the editor so a settings document written by
  /// hand in the console cannot poison the app without the reader finding out.
  List<String> validationProblems() {
    final problems = <String>[];
    if (name.trim().isEmpty) problems.add('Give the store a name.');
    if (closeMinutes <= openMinutes) {
      problems.add('Closing time must be after opening time.');
    }
    if (lowStockThreshold < minLowStockThreshold ||
        lowStockThreshold > maxLowStockThreshold) {
      problems.add(
        'The low-stock threshold must be between $minLowStockThreshold and '
        '$maxLowStockThreshold.',
      );
    }
    return problems;
  }

  /// Writes this model for Firestore. `updatedAt` is stamped server-side by
  /// the repository (`FieldValue.serverTimestamp`), not here: the writer's
  /// clock and the server's can disagree, and the log should read in one time.
  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'address': address,
      'phone': phone,
      'openMinutes': openMinutes,
      'closeMinutes': closeMinutes,
      'lowStockThreshold': lowStockThreshold,
      'expiryWarningDays': expiryWarningDays,
      'reorderCoverageDays': reorderCoverageDays,
      'updatedBy': updatedBy,
    };
  }

  /// A copy with the given fields replaced. Used by the settings screen's
  /// editors, which each change exactly one thing.
  StoreSettingsModel copyWith({
    String? name,
    String? address,
    String? phone,
    int? openMinutes,
    int? closeMinutes,
    int? lowStockThreshold,
    int? expiryWarningDays,
    int? reorderCoverageDays,
    String? updatedBy,
  }) {
    return StoreSettingsModel(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      openMinutes: openMinutes ?? this.openMinutes,
      closeMinutes: closeMinutes ?? this.closeMinutes,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      expiryWarningDays: expiryWarningDays ?? this.expiryWarningDays,
      reorderCoverageDays: reorderCoverageDays ?? this.reorderCoverageDays,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt,
    );
  }

  /// A copy with a nullable field cleared. [copyWith] cannot set `address` or
  /// `phone` back to null -- `address ?? this.address` would keep the old
  /// value -- so clearing an optional field goes through here instead.
  ///
  /// Empty strings and null are the same thing on the way in: an editor that
  /// was given whitespace hands back a cleared field rather than a field
  /// holding nothing but spaces.
  StoreSettingsModel withCleared({
    bool clearAddress = false,
    bool clearPhone = false,
  }) {
    return StoreSettingsModel(
      name: name,
      address: clearAddress ? null : address,
      phone: clearPhone ? null : phone,
      openMinutes: openMinutes,
      closeMinutes: closeMinutes,
      lowStockThreshold: lowStockThreshold,
      expiryWarningDays: expiryWarningDays,
      reorderCoverageDays: reorderCoverageDays,
      updatedBy: updatedBy,
      updatedAt: updatedAt,
    );
  }

  /// `8:30 AM`. Hand-rolled rather than `intl`, which this package does not
  /// carry: a twelve-hour clock is four lines, and the app's only other
  /// formatted value -- money -- is also written by hand.
  static String formatMinutes(int minutes) {
    final clamped = minutes.clamp(0, 24 * 60 - 1);
    final hour = clamped ~/ 60;
    final minute = clamped % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  static int _readMinutes(Object? value, int fallback) {
    if (value is! int) return fallback;
    if (value < 0 || value >= 24 * 60) return fallback;
    return value;
  }
}
