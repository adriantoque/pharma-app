/// Every route the feature finder can navigate to.
///
/// Mirrors the strings in `app_router.dart`. Kept here rather than imported from
/// `AppRoutes` because `AppRoutes` is `abstract final class` under
/// `core/navigation` and importing it into `data/repositories/` would make the
/// finder's data layer depend on the navigation module -- which is the wrong
/// direction, and would fight any future test that builds a catalogue without a
/// router.
///
/// The duplication is deliberate and small. A wrong value here does not fail to
/// compile: `go_router` throws when the row is tapped, in front of a user. That
/// is why `app_router.dart` and this file must be kept in step by hand, and why
/// the entries below are checked against the router in a test rather than left
/// to a code review.
abstract final class FeatureRoutes {
  static const String home = '/home';
  static const String expiringMeds = '/home/expiring';
  static const String scan = '/home/scan';
  static const String profile = '/home/profile';
  static const String notifications = '/home/notifications';

  static const String inventory = '/inventory';
  static const String orders = '/orders';
  static const String newSale = '/new-sale';
  static const String reports = '/reports';
}
