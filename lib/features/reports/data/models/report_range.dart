enum ReportRange {
  today('Today', 1),
  week('7 days', 7),
  month('30 days', 30);

  const ReportRange(this.label, this.days);

  final String label;
  final int days;

  static ReportRange fromDays(int days) {
    return switch (days) {
      1 => ReportRange.today,
      7 => ReportRange.week,
      30 => ReportRange.month,
      _ => ReportRange.week,
    };
  }
}
