import 'package:flutter/foundation.dart';

/// Where a sale came from.
///
/// A separate type rather than a flag, because the two are used differently
/// everywhere downstream: a named-customer order is real revenue but it is not
/// counter trade, and averaging it into "about 40 a day" would put a figure on
/// the shelf that the counter never sold. [isCounter] is the question every
/// calculation actually asks.
enum SaleKind {
  /// Walk-in trade off the counter sheets.
  counter,

  /// A named customer's standing or one-off order.
  bulk;

  static SaleKind parse(Object? value) => switch (value) {
        'bulk' => SaleKind.bulk,
        _ => SaleKind.counter,
      };

  bool get isCounter => this == SaleKind.counter;

  String get label => switch (this) {
        SaleKind.counter => 'Counter',
        SaleKind.bulk => 'Bulk order',
      };
}

/// One line of sales history, as read from the workbook.
///
/// Historical, not live: the pharmacy's records were a spreadsheet and this is
/// that spreadsheet after cleaning. Nothing in the app writes a sale yet, so
/// these are bundled and read rather than fetched.
@immutable
class SaleModel {
  const SaleModel({
    required this.date,
    required this.kind,
    required this.rawName,
    required this.key,
    required this.quantity,
    required this.priceCentavos,
    required this.totalCentavos,
    required this.sourceSheet,
  });

  /// The day the sale happened.
  ///
  /// The workbook records no year anywhere, so the importer states one for the
  /// whole run rather than guessing per row; see `salesYear` in the importer.
  final DateTime date;

  final SaleKind kind;

  /// The name exactly as it was written on the sheet.
  ///
  /// Kept even where it is a misspelling, because a report that cannot show what
  /// the counter actually wrote cannot be checked against the paper record.
  final String rawName;

  /// [rawName] normalised to letters and digits, which is how it is grouped.
  final String key;

  /// Units sold.
  ///
  /// A [num] and not an int, because the workbook has a couple of half-tablet
  /// lines. Rounding them would put a number in the report that nobody sold, and
  /// the whole point of a report is that it matches the paper.
  final num quantity;

  final int priceCentavos;

  final int totalCentavos;

  /// The sheet this came from, for tracing a figure back to its source.
  final String sourceSheet;

  /// How many distinct days this line's date falls on, for daily averages.
  DateTime get day => DateTime(date.year, date.month, date.day);

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    return SaleModel(
      date: _parseDate(json['date']),
      kind: SaleKind.parse(json['kind']),
      rawName: json['rawName'] as String? ?? '',
      key: json['key'] as String? ?? '',
      quantity: (json['quantity'] as num?) ?? 0,
      priceCentavos: (json['priceCentavos'] as num?)?.round() ?? 0,
      totalCentavos: (json['totalCentavos'] as num?)?.round() ?? 0,
      sourceSheet: json['sourceSheet'] as String? ?? '',
    );
  }

  /// Parsed by hand so a missing or malformed date cannot throw while the whole
  /// report is loading. An unparseable date becomes the epoch, which sorts first
  /// and is excluded from the date range by [isOnARealDate] rather than quietly
  /// widening the range to 1970.
  static DateTime _parseDate(Object? value) {
    if (value is! String) return DateTime.fromMillisecondsSinceEpoch(0);
    final parts = value.split(RegExp('[T ]')).first.split('-');
    if (parts.length != 3) return DateTime.fromMillisecondsSinceEpoch(0);
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null || month < 1 || month > 12) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime(year, month, day);
  }

  /// Whether this line has a date that was actually in the workbook.
  bool get isOnARealDate => date.year > 1970;
}
