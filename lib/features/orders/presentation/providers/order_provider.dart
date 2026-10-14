import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/lifecycle/disposable_store.dart';
import '../../../../core/utils/currency.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../search/data/repositories/medicine_repository.dart';
import '../../data/models/order_line_model.dart';
import '../../data/models/order_history_model.dart';
import '../../data/repositories/order_draft_store.dart';
import '../../data/repositories/order_history_repository.dart';

/// The order being built up in the signed-in area.
///
/// Created by `main.dart` above the router, so it survives switching tabs.
///
/// ## Surviving the app closing
///
/// A basket that is only in memory is a basket that disappears if the tablet
/// sleeps, the battery goes, or Android kills the process -- which it will, given
/// long enough, and routinely on a cheap device under memory pressure. A
/// customer standing at the counter with a part-built order does not care why.
///
/// So when the app has somewhere to put it, the order is written through an
/// [OrderDraftStore] on every change and read back when the account signs in
/// again. [draftFor] is optional and [auth] may be null, so a caller with neither
/// -- which is every test -- keeps a basket that lasts exactly as long as the
/// process, exactly as before.
///
/// The catalogue is handed in too, for the same reason: a restored line carries
/// a medicine's identity and nothing else, and the identity has to be matched
/// against the price list that is actually on screen before the shelf's count is
/// believed.
class OrderProvider extends ChangeNotifier {
  OrderProvider({
    AuthProvider? auth,
    OrderDraftStore Function(String uid)? draftFor,
    MedicineRepository? catalogue,
    OrderHistoryRepository Function(String uid)? historyFor,
  }) // A named parameter cannot be private, so these two cannot be initializing
    // formals.
    // ignore: prefer_initializing_formals
    : _draftFor = draftFor,
       // ignore: prefer_initializing_formals
       _catalogue = catalogue,
       _historyForFactory = historyFor {
    // A shared counter tablet is signed in and out all day, and a basket left
    // behind by the last user is both a privacy problem and a confusing screen.
    // Watching auth is cheaper than trying to clear the order from the sign-out
    // button, which is not the only route out of a session.
    if (auth != null) {
      _auth = auth;
      // Called on the parameter, not on [_auth]: a nullable field is not promoted
      // by an assignment, so `auth` is the only name the analyzer will accept.
      auth.addListener(_onAuthChanged);
      // Run once rather than waiting for the first auth event. A cold start
      // resolves auth asynchronously, and without this the draft would not be
      // read until something else happened to make the provider speak.
      _onAuthChanged();
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
  /// An item nobody has counted ([MedicineModel.isStockUnknown]) caps at
  /// [maxQuantity] instead of zero. Not knowing the count is not the same as
  /// having none, and a null that fell through as 0 would block ordering every
  /// product in an imported catalogue -- the app would refuse the sale of things
  /// that are almost certainly on the shelf, on the strength of a number nobody
  /// entered. The 99 ceiling is still there to catch a mistyped quantity.
  ///
  /// Static so the quantity sheet and the orders list can ask the same question
  /// without needing a provider instance to hand.
  static int capFor(MedicineModel medicine) {
    final stock = medicine.stock;
    if (stock != null && stock < minQuantity) return 0;
    return (stock ?? maxQuantity).clamp(minQuantity, maxQuantity);
  }

  final List<OrderLineModel> _lines = [];

  AuthProvider? _auth;
  final OrderDraftStore Function(String uid)? _draftFor;
  final MedicineRepository? _catalogue;
  final OrderHistoryRepository Function(String uid)? _historyForFactory;

  OrderDraftStore? _draftStore;
  StreamSubscription<List<OrderLineModel>>? _draftSubscription;

  /// The account the current draft belongs to.
  String? _uid;

  /// Whether the stored draft has been read in yet.
  ///
  /// Only used to avoid saving a draft that is about to be overwritten by it. The
  /// alternative -- writing the empty order on sign-in and then restoring over
  /// the top of it -- works, and quietly destroys the draft on any device whose
  /// stored copy arrives a moment after the write does.
  bool _restored = false;

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
    _saveDraft();
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
    _saveDraft();
  }

  /// Removes every unit of [medicine]. A no-op if it is not in the order, so
  /// two taps in a row cannot notify for nothing.
  void remove(MedicineModel medicine) => setQuantity(medicine, 0);

  /// Empties the order.
  void clear() {
    if (_lines.isEmpty) return;
    _lines.clear();
    _safeNotify();
    _saveDraft();
  }

  /// Completes the current order, saves it to history, and clears the cart.
  ///
  /// Requires at least one item in the order.
  /// Returns true on success, false if the order cannot be completed.
  bool complete() {
    if (isEmpty) return false;

    final historyFactory = _historyForFactory;
    if (historyFactory == null) return false;
    if (_uid == null) return false;

    final history = historyFactory(_uid!);
    final order = OrderHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      time: DateTime.now(),
      status: OrderStatus.new_,
      items: List.unmodifiable(_lines),
      totalCentavos: totalCentavos,
    );

    unawaited(history.save(order));
    clear();
    return true;
  }

  /// Switches the draft store over when the account changes, and drops the
  /// previous account's basket on the way out.
  ///
  /// The stored draft is left alone on the way out, deliberately. It is written
  /// under `users/{uid}` and the security rules keep it there, so nobody else can
  /// read it, and deleting it would throw away a part-built order over a session
  /// the user did not mean to end.
  void _onAuthChanged() {
    final user = _auth?.user;

    if (user == null) {
      // Only a signed-*out* state empties the order. Auth also fires while
      // resolving a cold start, where the status is still `unknown` and the user
      // is perfectly signed in, and that must not wipe a basket mid-session.
      if (_auth?.status != AuthStatus.unauthenticated) return;
      _releaseDraft();
      _lines.clear();
      _safeNotify();
      return;
    }

    // A different user is worth reacting to; a refresh of the same one is not.
    // On a shared counter tablet the session can be replaced underneath the app,
    // and a store still pointed at the previous account would either throw or
    // quietly save one user's basket over another's.
    if (_uid == user.id) return;
    _releaseDraft();
    _uid = user.id;
    _lines.clear();
    _safeNotify();
    _attachDraft(user.id);
  }

  void _attachDraft(String uid) {
    final draftFor = _draftFor;
    if (draftFor == null) return;

    final store = draftFor(uid);
    _draftStore = store;
    _draftSubscription = store.watchDraft().listen(_adoptDraft);
  }

  /// Puts a stored draft on screen, matched against the live price list.
  ///
  /// A restored line carries its product ID when available, or the older
  /// name/price identity. Matching it against the live catalogue brings back the
  /// current stock count, aliases and expiry. If a legacy identity could refer
  /// to multiple packages, it stays unresolved rather than choosing one.
  ///
  /// A line whose product is no longer in the price list keeps the stored copy,
  /// with no count. Silently deleting somebody's line because the catalogue moved
  /// under it would be worse than showing them something they can see and remove,
  /// and with no count it falls back to the ordinary order limit rather than
  /// claiming the shelf is empty.
  void _adoptDraft(List<OrderLineModel> draft) {
    if (_disposed) return;
    _restored = true;

    final catalogue = _catalogue;
    _lines
      ..clear()
      ..addAll([
        for (final line in draft)
          line.copyWith(medicine: _resolve(catalogue, line.medicine)),
      ]);
    _safeNotify();
  }

  /// The catalogue's copy of [stored], or [stored] itself if it has none.
  static MedicineModel _resolve(
    MedicineRepository? catalogue,
    MedicineModel stored,
  ) {
    if (catalogue == null) return stored;
    final medicines = catalogue.all();
    for (final medicine in medicines) {
      if (medicine == stored) return medicine;
    }

    if (stored.productId == null) {
      final legacyMatches = medicines.where(
        (medicine) =>
            medicine.name == stored.name &&
            medicine.priceCentavos == stored.priceCentavos &&
            (stored.packageType == null ||
                medicine.packageType == stored.packageType),
      );
      if (legacyMatches.length == 1) return legacyMatches.single;
    }

    return stored;
  }

  /// Writes the current order out, if there is anywhere to write it.
  ///
  /// Silent on failure, because Firestore resolves a write the moment it has been
  /// applied locally and the only thing that can fail here is the security rules.
  /// A basket that could not be saved has still been built, and turning that into
  /// an error would mean throwing away what the pharmacist did in favour of
  /// telling them it did not work.
  ///
  /// Held back until [_restored], for the reason on that field.
  void _saveDraft() {
    final store = _draftStore;
    if (store == null || !_restored) return;
    unawaited(store.save(List<OrderLineModel>.unmodifiable(_lines)));
  }

  void _releaseDraft() {
    unawaited(_draftSubscription?.cancel());
    _draftSubscription = null;
    final store = _draftStore;
    _draftStore = null;
    if (store case final DisposableStore disposable) disposable.dispose();
    _uid = null;
    _restored = false;
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
    _releaseDraft();
    super.dispose();
  }
}
