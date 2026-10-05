import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device believes it has a route to the internet.
///
/// An interface rather than a platform type for the same reason
/// `PrescriptionCamera` is one: `connectivity_plus` is a platform channel, and
/// the store that consumes this has to be driveable in a test without one.
///
/// Lives in `core` rather than inside a feature because the answer is not the
/// search feature's business -- the price list, the order draft and ML Kit's
/// model download all need it, and three copies of the same platform call would
/// drift.
abstract interface class ConnectionSource {
  /// Whether a network is currently attached, right now.
  ///
  /// Null until the platform has answered, so "not asked yet" is not confused
  /// with "asked and there is none". See [hasConnection].
  bool? get isConnected;

  /// The current answer to every new subscriber, then every change.
  ///
  /// The leading emission matters: a listener that only heard about changes
  /// would sit on a stale answer for as long as the connection stayed steady,
  /// which is exactly the case the banner has to be right about.
  Stream<bool> watch();
}

/// An extension rather than a member: an `abstract interface class` may not
/// declare a member with a body, and every implementation of the interface would
/// otherwise have to repeat this one line of arithmetic.
extension ConnectionSourceReachability on ConnectionSource {
  /// Whether the device is not reporting a lost network.
  ///
  /// A lost network is a certainty; an unanswered question is not one, and this
  /// treats it as the weaker of the two. The offline banner is better a moment
  /// late than wrong.
  bool get hasConnection => isConnected != false;
}

/// [ConnectionSource] backed by the operating system.
///
/// The platform reports which kind of network is attached, not whether anything
/// is reachable through it: a shop wifi behind a captive portal reports
/// `wifi` quite happily while every request hangs. So this is used to catch the
/// loss of a connection *early* -- before Firestore's own retry has given up and
/// told us -- and never to claim the device is online. A stream that has gone
/// quiet is not evidence of anything.
class PlatformConnectionSource implements ConnectionSource {
  PlatformConnectionSource({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  bool? _isConnected;
  StreamController<bool>? _controller;

  @override
  bool? get isConnected => _isConnected;

  @override
  Stream<bool> watch() {
    // One subscription for the life of the process however many callers there
    // are: the platform stream is already broadcast, and re-subscribing per
    // caller would mean a channel event arriving while nobody is listening and
    // the next listener starting from a value that no longer holds.
    final existing = _controller;
    if (existing != null) return existing.stream;

    late final StreamController<bool> controller;
    controller = StreamController<bool>.broadcast(
      onListen: () {
        // Hand the answer already held to whoever just subscribed, before the
        // refresh below goes looking for a newer one. Without this a listener
        // joining after the last one left waits forever: `onCancel` tore down
        // the platform subscription, `onListen` starts it again, and `_refresh`
        // finds the answer unchanged -- so `_publish` declines to emit and the
        // late listener sits on a stream that only carries changes.
        //
        // Both listeners being served means the current value goes out once
        // through here; the refresh that follows publishes again only if the
        // answer actually moved.
        final known = _isConnected;
        if (known != null) controller.add(known);
        unawaited(_refresh());
        _subscription = _connectivity.onConnectivityChanged.listen(
          (results) => _publish(_fromTypes(results)),
          onError: (Object _) {
            // A channel that will not answer is not a lost connection. The store
            // keeps whatever it last knew, which is the same thing this class
            // does when the app starts.
          },
        );
      },
      onCancel: () {
        _subscription?.cancel();
        _subscription = null;
      },
    );
    _controller = controller;
    return controller.stream;
  }

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// [ConnectivityResult.none] is the only one that means there is no route.
  ///
  /// Anything else counts as connected, including the transports the platform
  /// cannot enumerate -- a USB tether or a VPN shows up as `none` on some
  /// devices and as `wifi` on others, and treating the first as no network
  /// would take the app offline while it was plainly online.
  static bool _fromTypes(List<ConnectivityResult> results) =>
      !results.contains(ConnectivityResult.none);

  Future<void> _refresh() async {
    try {
      _publish(_fromTypes(await _connectivity.checkConnectivity()));
    } on Object {
      // Same reasoning as the change stream's error handler: no answer is not a
      // negative answer.
    }
  }

  void _publish(bool connected) {
    if (_isConnected == connected) return;
    _isConnected = connected;
    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    controller.add(connected);
  }
}