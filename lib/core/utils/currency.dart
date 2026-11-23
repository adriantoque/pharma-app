/// Formats [centavos] as `₱4.00`.
///
/// Integer arithmetic throughout, so a price that lands on a half peso is stored
/// and printed exactly and there is no floating-point rounding to reason about.
///
/// Lives in core rather than on [MedicineModel] because three places need it:
/// the price list, an order line and the order total. Formatting pesos once here
/// is what stops a line total and a grand total from disagreeing.
String formatCentavos(int centavos) {
  final pesos = centavos ~/ 100;
  final fraction = (centavos % 100).toString().padLeft(2, '0');
  return '₱$pesos.$fraction';
}
