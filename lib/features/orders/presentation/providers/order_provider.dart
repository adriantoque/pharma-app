import 'package:flutter/foundation.dart';

import '../../../../core/utils/currency.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../data/models/order_line_model.dart';

/// The order being built up in the signed-in area.
///
/// Deliberately in memory: it is created by `main.dart` above the router, so it
/// survives switching tabs, and it is thrown away when the app exits. There is
/// no order repository yet, so persisting this means adding one and swapping the
/// provider's internals, the same seam [MedicineRepository] already provides for
/// the price list.
class OrderProvider extends ChangeNotifier {
  OrderProvider({AuthProvider? auth}) {
    // A shared counter tablet is signed in and out all day, and a basket left
    // behind by the last user is both a privacy problem and a confusing screen.
    // Watching auth is cheaper than trying to clear the order from the sign-out
    // button, which is not the only route out of a session.
    if (auth != null) {
      _auth = auth;
      // Called on the parameter, not on [_auth]: a nullable field is not promoted
      // by an assignment, so `auth` is the only name the analyzer will accept.
      auth.addListener(_onAuthChanged);
    }
  }

  /// Fewest units that can be ordered. A line of zero is a removed line, not a
  /// line, so there is no zero-quantity state to render.
  static const int minQuantity = 1;

  /// Most units of one item in a single order. A counter mostly deals in
  /// single digits; the cap is there to stop a mistyped 999999 becoming a
  /// 375000-peso line nobody notices.
  static const int maxQuantity = 99;

  /// The most of [medicine] one order may hold: whatever is on the shelf, but
  /// never more than [maxQuantity].
  ///
  /// Zero for an out-of-stock item, which is the one answer that falls below
  /// [minQuantity]. That gap is real and worth keeping: "you may not have any
  /// of this" and "you may have one" are different answers, and rounding 0 up
  /// to 1 would hand out stock the shelf does not have.
  ///
  /// Static so the quantity sheet and the orders list can ask the same question
  /// without needing a provider instance to hand.
  static int capFor(MedicineModel medicine) => medicine.stock < minQuantity
      ? 0
      : medicine.stock.clamp(minQuantity, maxQuantity);

  final List<OrderLineModel> _lines = [];

  AuthProvider? _auth;
  bool _disposed = false;

  /// The lines, oldest first, safe to hand to a widget: callers cannot reorder
  /// the provider's own list through the returned reference.
  List<OrderLineModel> get lines => List.unmodifiable(_lines);

  bool get isEmpty => _lines.isEmpty;

  bool get isNotEmpty => _lines.isNotEmpty;

  /// Total number of units across every line, which is not the number of lines.
  int get itemCount => _lines.fold(0, (total, line) => total + line.quantity);

  /// Sum of the line totals, in centavos, accumulated as integers.
  int get totalCentavos =>
      _lines.fold(0, (total, line) => total + line.totalCentavos);

  /// `₱180.00`, the whole order.
  String get formattedTotal => formatCentavos(totalCentavos);

  /// How many of [medicine] are already ordered, or 0 if it is not in the order.
  ///
  /// Matches on name *and* price, per [MedicineModel]'s identity rule, so the
  /// ₱4.00 `Amox` and the ₱45.00 one are counted apart.
  int quantityOf(MedicineModel medicine) {
    for (final line in _lines) {
      if (line.medicine == medicine) return line.quantity;
    }
    return 0;
  }

  /// Adds [quantity] units of [medicine], merging into an existing line rather
  /// than adding a second one for the same item.
  ///
  /// Adding an item already in the order increases its quantity, so a customer
  /// asking for three then another two of the same thing ends up with one line
  /// of five.
  ///
  /// The result is capped at [capFor] -- a shelf holding ten cannot take an
  /// order for twelve, however the twelve arrives. The clamping happens here
  /// rather than in the widgets on purpose: the disabled `+` button is only an
  /// affordance, and this is the part that actually holds.
  void add(MedicineModel medicine, int quantity) {
    if (quantity < minQuantity) return;
    // Nothing on the shelf means nothing orderable, at any quantity.
    if (capFor(medicine) < minQuantity) return;

    final index = _indexOf(medicine);
    final merged = index == -1 ? quantity : _lines[index].quantity + quantity;
    final capped = _capTo(medicine, merged);

    if (index == -1) {
      _lines.add(OrderLineModel(medicine: medicine, quantity: capped));
    } else {
      _lines[index] = _lines[index].copyWith(quantity: capped);
    }
    _safeNotify();
  }

  /// Sets the quantity of [medicine] to [quantity], removing the line if it is
  /// less than [minQuantity], more than the item has in stock, or the item is
  /// not in the order at all.
  void setQuantity(MedicineModel medicine, int quantity) {
    final index = _indexOf(medicine);
    if (index == -1) return;

    final capped = _capTo(medicine, quantity);
    if (capped < minQuantity) {
      _lines.removeAt(index);
    } else {
      _lines[index] = _lines[index].copyWith(quantity: capped);
    }
    _safeNotify();
  }

  /// Removes every unit of [medicine]. A no-op if it is not in the order, so
  /// two taps in a row cannot notify for nothing.
  void remove(MedicineModel medicine) => setQuantity(medicine, 0);

  /// Empties the order.
  void clear() {
    if (_lines.isEmpty) return;
    _lines.clear();
    _safeNotify();
  }

  int _indexOf(MedicineModel medicine) {
    for (var i = 0; i < _lines.length; i++) {
      if (_lines[i].medicine == medicine) return i;
    }
    return -1;
  }

  /// [quantity] pulled down to what the shelf can actually supply.
  ///
  /// Only ever lowers. A request below [minQuantity] has to come back
  /// unchanged so callers can still tell "no line at all" from "one line": a
  /// `clamp` here would quietly turn a removal into a 1-unit line, because
  /// clamping 0 up into 1..99 gives 1.
  static int _capTo(MedicineModel medicine, int quantity) {
    final cap = capFor(medicine);
    return cap < quantity ? cap : quantity;
  }

  void _onAuthChanged() {
    // Only a *change* to signed-out empties the order. Auth also fires while
    // resolving a cold start, and that must not wipe a basket mid-session.
    if (_auth?.status == AuthStatus.unauthenticated) clear();
  }

  /// Notifying a disposed ChangeNotifier throws, and the auth listener is only
  /// detached in [dispose] -- which auth can still reach during its own dispose
  /// on sign-out.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _auth?.removeListener(_onAuthChanged);
    _auth = null;
    super.dispose();
  }
}
