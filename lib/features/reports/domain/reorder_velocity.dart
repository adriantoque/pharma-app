import '../../../core/utils/search_text.dart';
import '../../search/data/models/medicine_model.dart';
import '../../orders/data/models/order_history_model.dart';
import '../data/models/sale_model.dart';

/// How fast one product sells, as the reorder maths needs it.
///
/// [unitsPerDay] divides by days *with* sales, not calendar days: a pharmacy
/// that trades four days a week should not have its rate quietly halved by
/// Sundays nobody sold on. The same convention [SalesSummary] uses for the
/// whole-period figure, applied here per product.
class SalesUsage {
  const SalesUsage({required this.units, required this.daysWithSales});

  /// Units sold across the whole period. A [num] because the workbook has
  /// fractional lines (half tablets) and rounding them would put a number in
  /// the report nobody sold.
  final num units;

  /// Distinct calendar days with at least one sale.
  final int daysWithSales;

  /// Zero when there was no trade at all, rather than a division by zero.
  double get unitsPerDay => daysWithSales == 0 ? 0 : units / daysWithSales;
}

/// Groups the bundled seed's sale lines by their normalised key.
///
/// Unreal dates (the epoch the tolerant date parser invents for a broken row)
/// are skipped: a line whose date is not real contributes units nobody can
/// place in time, and counting its day would put a phantom day in the average.
Map<String, SalesUsage> usageBySaleKey(List<SaleModel> lines) {
  final units = <String, num>{};
  final days = <String, Set<DateTime>>{};
  for (final sale in lines) {
    if (!sale.isOnARealDate) continue;
    units[sale.key] = (units[sale.key] ?? 0) + sale.quantity;
    days.putIfAbsent(sale.key, () => <DateTime>{}).add(sale.day);
  }
  return {
    for (final entry in units.entries)
      entry.key: SalesUsage(
        units: entry.value,
        daysWithSales: days[entry.key]!.length,
      ),
  };
}

/// Groups live approved order history by normalised medicine name.
///
/// Only approved orders count: a rejected order was never sold, and a pending
/// one may still not be. The key is the same normalisation the bundled seed's
/// keys use, so the two maps are interchangeable to a lookup.
Map<String, SalesUsage> usageByOrderKey(List<OrderHistory> orders) {
  final units = <String, num>{};
  final days = <String, Set<DateTime>>{};
  for (final order in orders) {
    if (order.status != OrderStatus.approved) continue;
    final day = DateTime(order.time.year, order.time.month, order.time.day);
    for (final item in order.items) {
      final key = normaliseForSearch(item.medicine.name);
      if (key.isEmpty) continue;
      units[key] = (units[key] ?? 0) + item.quantity;
      days.putIfAbsent(key, () => <DateTime>{}).add(day);
    }
  }
  return {
    for (final entry in units.entries)
      entry.key: SalesUsage(
        units: entry.value,
        daysWithSales: days[entry.key]!.length,
      ),
  };
}

/// The catalogue line's keys a sale could have been written under.
///
/// The name first, then the aliases the counter has actually used: a sale
/// recorded as `ceterizine` should feed the velocity of the line the list
/// calls `Cetirizine`. Deduplicated, because [aliases] may repeat the name.
List<String> _keysFor(MedicineModel medicine) {
  final keys = <String>[];
  for (final spelling in [medicine.name, ...medicine.aliases]) {
    final key = normaliseForSearch(spelling);
    if (key.isNotEmpty && !keys.contains(key)) keys.add(key);
  }
  return keys;
}

/// How fast [medicine] sells, live history first, bundled seed as the fallback.
///
/// Live history wins per key rather than being summed with the seed: the seed
/// covers months that have already happened and the history covers the months
/// since, but a store that ran both sources over the same month would count
/// that month twice. Where the history has nothing for the item at all -- a
/// product that has not moved since the records began -- the seed's slower,
/// older picture is still better than nothing, and nothing at all comes back
/// as 0.
double unitsPerDayForMedicine(
  MedicineModel medicine,
  Map<String, SalesUsage> liveUsage,
  Map<String, SalesUsage> seedUsage,
) {
  final keys = _keysFor(medicine);
  for (final source in [liveUsage, seedUsage]) {
    for (final key in keys) {
      final usage = source[key];
      if (usage != null && usage.daysWithSales > 0) return usage.unitsPerDay;
    }
  }
  return 0;
}

/// The reorder point the deficit is measured against.
///
/// Velocity first -- enough units to cover [coverageDays] at the observed
/// rate, rounded up because a shelf holds whole units -- but never below
/// [threshold]. An item that barely sells would otherwise get a target of
/// zero and a deficit of zero while still sitting below the low-stock alert
/// level: an alert that fires with nothing to act on. The floor means a slow
/// mover reorders at least a threshold's worth, so every row on the alert
/// list has a number bigger than its stock.
int reorderTarget({
  required double unitsPerDay,
  required int coverageDays,
  required int threshold,
}) {
  final velocityTarget = (unitsPerDay * coverageDays).ceil();
  return velocityTarget > threshold ? velocityTarget : threshold;
}
