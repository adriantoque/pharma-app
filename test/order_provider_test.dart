import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/auth/presentation/providers/auth_provider.dart';
import 'package:pharmaguide/features/orders/data/models/order_line_model.dart';
import 'package:pharmaguide/features/orders/presentation/providers/order_provider.dart';
import 'package:pharmaguide/features/search/data/models/medicine_model.dart';

import 'helpers/fake_auth_repository.dart';

void main() {
  // The catalog deliberately repeats names at different prices. Every lookup
  // here is by name *and* price, so these two must never be confused.
  const cheapAmox = MedicineModel(name: 'Amox', priceCentavos: 400, stock: 200);
  const dearAmox = MedicineModel(name: 'Amox', priceCentavos: 4500, stock: 200);
  const cheapTramadol = MedicineModel(
    name: 'Tramadol',
    priceCentavos: 400,
    stock: 200,
  );
  const dearTramadol = MedicineModel(
    name: 'Tramadol',
    priceCentavos: 1000,
    stock: 200,
  );

  group('OrderProvider', () {
    late OrderProvider order;

    setUp(() => order = OrderProvider());
    tearDown(() => order.dispose());

    test('starts empty', () {
      expect(order.isEmpty, isTrue);
      expect(order.isNotEmpty, isFalse);
      expect(order.lines, isEmpty);
      expect(order.itemCount, 0);
      expect(order.totalCentavos, 0);
      expect(order.formattedTotal, '₱0.00');
    });

    test('add creates a line and totals it', () {
      order.add(dearAmox, 3);

      expect(order.isNotEmpty, isTrue);
      expect(order.lines, hasLength(1));
      expect(order.lines.single.medicine, dearAmox);
      expect(order.lines.single.quantity, 3);
      expect(order.itemCount, 3);
      // 4500 * 3, as integer arithmetic rather than 45.0 * 3.
      expect(order.totalCentavos, 13500);
      expect(order.formattedTotal, '₱135.00');
    });

    test('a half-peso price totals exactly', () {
      // The catalog contains a 2.50 item precisely because a price with centavos
      // has to survive the round trip; a double-based total would drift here.
      const half = MedicineModel(
        name: 'Aspirin',
        priceCentavos: 250,
        stock: 200,
      );

      order.add(half, 3);

      expect(order.totalCentavos, 750);
      expect(order.formattedTotal, '₱7.50');
      expect(order.lines.single.formattedTotal, '₱7.50');
    });

    test('the same name at a different price is a different line', () {
      order.add(cheapAmox, 2);
      order.add(dearAmox, 1);

      expect(order.lines, hasLength(2));
      expect(order.itemCount, 3);
      // 400 * 2 + 4500 * 1.
      expect(order.totalCentavos, 5300);
      expect(order.quantityOf(cheapAmox), 2);
      expect(order.quantityOf(dearAmox), 1);
    });

    test('adding an item twice merges into one line', () {
      order.add(cheapTramadol, 2);
      order.add(cheapTramadol, 3);

      // Three Tramadol lines for three of the same product would read as three
      // separate purchases at the counter.
      expect(order.lines, hasLength(1));
      expect(order.itemCount, 5);
      expect(order.quantityOf(cheapTramadol), 5);
    });

    test('a repeated add is matched by price, not by name', () {
      order.add(dearTramadol, 2);

      // Same shorthand name, different money. This must not merge into the ₱4
      // line, because a customer asking for both wants two different items.
      order.add(cheapTramadol, 1);

      expect(order.lines, hasLength(2));
      expect(order.quantityOf(dearTramadol), 2);
      expect(order.quantityOf(cheapTramadol), 1);
    });

    test('setQuantity replaces the amount in place', () {
      order.add(cheapAmox, 2);
      order.add(dearAmox, 1);

      order.setQuantity(dearAmox, 6);

      expect(order.lines, hasLength(2));
      expect(order.quantityOf(dearAmox), 6);
      expect(order.quantityOf(cheapAmox), 2);
    });

    test('setting a quantity below one removes the line', () {
      order.add(dearAmox, 3);

      order.setQuantity(dearAmox, 0);

      expect(order.isEmpty, isTrue);
      expect(order.totalCentavos, 0);
    });

    test('remove takes out every unit of that item only', () {
      order.add(cheapAmox, 2);
      order.add(dearAmox, 1);

      order.remove(cheapAmox);

      expect(order.lines, hasLength(1));
      expect(order.lines.single.medicine, dearAmox);
      expect(order.totalCentavos, 4500);
    });

    test('a repeated add is capped rather than allowed to run away', () {
      order.add(dearAmox, OrderProvider.maxQuantity);
      order.add(dearAmox, 5);

      expect(order.quantityOf(dearAmox), OrderProvider.maxQuantity);
    });

    test('setQuantity is capped at the maximum', () {
      order.add(dearAmox, 1);

      order.setQuantity(dearAmox, 5000);

      expect(order.quantityOf(dearAmox), OrderProvider.maxQuantity);
    });

    test('an add of zero or less is ignored', () {
      order.add(dearAmox, 0);
      order.add(dearAmox, -3);

      expect(order.isEmpty, isTrue);
    });

    test('quantities of items not in the order report zero', () {
      expect(order.quantityOf(dearAmox), 0);

      order.add(dearAmox, 2);
      expect(order.quantityOf(cheapAmox), 0);
    });

    test('mutating an item that is not in the order does nothing', () {
      order.add(dearAmox, 2);
      var notifications = 0;
      order.addListener(() => notifications++);

      order.setQuantity(cheapAmox, 5);
      order.remove(cheapAmox);

      // Nothing changed, so nothing is announced; a listener rebuilding for no
      // reason is exactly the kind of thing that turns into a janky list.
      expect(notifications, 0);
      expect(order.quantityOf(dearAmox), 2);
    });

    test('the lines handed out cannot be used to mutate the order', () {
      order.add(dearAmox, 2);

      // An unmodifiable view, not the provider's own list: a widget that sorted
      // or removed from it would otherwise reorder or truncate the order.
      expect(
        () => order.lines.add(
          const OrderLineModel(medicine: cheapAmox, quantity: 1),
        ),
        throwsUnsupportedError,
      );
    });

    test('clear empties the order', () {
      order.add(cheapAmox, 2);
      order.add(dearAmox, 1);

      order.clear();

      expect(order.isEmpty, isTrue);
      expect(order.totalCentavos, 0);
    });

    test('every change is announced once', () {
      var notifications = 0;
      order.addListener(() => notifications++);

      order.add(dearAmox, 2);
      order.add(dearAmox, 1);
      order.setQuantity(dearAmox, 5);
      order.remove(dearAmox);

      expect(notifications, 4);
    });
  });

  // The shelf is the real ceiling on an order. These tests deliberately call the
  // provider directly rather than through the widgets, because a disabled button
  // is only an affordance -- this is the part that has to hold even if some
  // future caller skips the UI.
  group('the stock cap', () {
    late OrderProvider order;

    const none = MedicineModel(name: 'X', priceCentavos: 100, stock: 0);
    const three = MedicineModel(name: 'X', priceCentavos: 100, stock: 3);
    const twoHundred = MedicineModel(name: 'X', priceCentavos: 100, stock: 200);

    setUp(() => order = OrderProvider());
    tearDown(() => order.dispose());

    test('is the shelf count, or the order limit, whichever is lower', () {
      expect(OrderProvider.capFor(none), 0);
      expect(OrderProvider.capFor(three), 3);
      expect(OrderProvider.capFor(twoHundred), OrderProvider.maxQuantity);
    });

    test('is zero for an item that has none', () {
      // Below the minimum on purpose: "you may not have any" and "you may have
      // one" are different answers.
      expect(OrderProvider.capFor(none), lessThan(OrderProvider.minQuantity));
    });

    test('an add of more than the shelf holds stops at the shelf', () {
      order.add(three, 12);

      expect(order.quantityOf(three), 3);
      expect(order.itemCount, 3);
    });

    test('a merge cannot push a line past the shelf', () {
      order.add(three, 2);
      order.add(three, 9);

      expect(order.lines, hasLength(1), reason: 'merged, not a second line');
      expect(order.quantityOf(three), 3);
    });

    test('a set beyond the shelf stops at the shelf', () {
      order.add(three, 1);

      order.setQuantity(three, 500);

      expect(order.quantityOf(three), 3);
    });

    test('an out-of-stock item cannot be ordered at all', () {
      order.add(none, 1);
      order.add(none, 50);

      expect(order.isEmpty, isTrue);
    });

    test('an item with plenty is still held to the order limit', () {
      order.add(twoHundred, 5000);

      expect(order.quantityOf(twoHundred), OrderProvider.maxQuantity);
    });

    test('taking a line below one still removes it', () {
      // The lower bound and the cap are different jobs. Clamping 0 up into the
      // valid range would turn a removal into a one-unit line.
      order.add(three, 3);

      order.setQuantity(three, 0);
      expect(order.isEmpty, isTrue);

      order.add(three, 3);
      order.setQuantity(three, -5);
      expect(order.isEmpty, isTrue);
    });

    test('the same name at a different price has its own shelf', () {
      const cheap = MedicineModel(name: 'Y', priceCentavos: 100, stock: 2);
      const dear = MedicineModel(name: 'Y', priceCentavos: 200, stock: 50);

      order.add(cheap, 10);
      order.add(dear, 10);

      expect(order.quantityOf(cheap), 2);
      expect(order.quantityOf(dear), 10);
    });
  });

  group('signing out', () {
    late FakeAuthRepository repository;
    late AuthProvider auth;
    late OrderProvider order;

    setUp(() async {
      repository = FakeAuthRepository();
      auth = AuthProvider(repository);
      await auth.ready;
      await auth.login(email: 'a@b.com', password: 'secret');
      order = OrderProvider(auth: auth);
    });

    tearDown(() {
      order.dispose();
      auth.dispose();
      repository.dispose();
    });

    // A counter tablet is shared, and a basket left behind by the previous user
    // is both a privacy problem and a screen the next person cannot explain.
    test('empties the order', () async {
      order.add(dearAmox, 3);
      expect(order.isNotEmpty, isTrue);

      await auth.logout();
      await Future<void>.delayed(Duration.zero);

      expect(auth.status, AuthStatus.unauthenticated);
      expect(order.isEmpty, isTrue);
    });

    test('leaves the order alone while still signed in', () async {
      order.add(dearAmox, 3);

      // A cold start fires auth changes as the session resolves, and signing in
      // as someone else fires one too. Neither is a sign-out, and neither may
      // read as one and wipe a basket.
      await auth.login(email: 'c@d.com', password: 'secret');
      await Future<void>.delayed(Duration.zero);

      expect(auth.status, AuthStatus.authenticated);
      expect(order.quantityOf(dearAmox), 3);
    });
  });
}
