/// How a customer is paying for a sale.
///
/// Lives in `domain/` rather than inside a screen so both the sale screen and
/// the cart screen can name it without importing each other. The order of the
/// values is the order they appear in the selector.
enum PaymentMethod {
  cashOnHand,
  gcash;

  /// What the method is called in front of a person.
  ///
  /// A getter rather than a `toString()` so the enum stays safe to interpolate
  /// in a log without a pharmacist reading "PaymentMethod.cashOnHand".
  String get label => switch (this) {
        PaymentMethod.cashOnHand => 'Cash on Hand',
        PaymentMethod.gcash => 'GCash',
      };
}