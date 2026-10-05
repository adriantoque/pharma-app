import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/connectivity/connection_source.dart';

/// A [ConnectivityPlatform] that answers however the test tells it to.
///
/// Extends rather than implements, because the interface verifies its own token
/// on assignment and an `implements` class does not carry it.
class _FakeConnectivityPlatform extends ConnectivityPlatform {
  final StreamController<List<ConnectivityResult>> _changes =
      StreamController<List<ConnectivityResult>>.broadcast();

  /// What `checkConnectivity` answers. The list rather than a bool, because the
  /// source's whole job is reading which transports are attached.
  List<ConnectivityResult> current = const [ConnectivityResult.wifi];

  /// When set, `checkConnectivity` throws this instead of answering.
  Object? checkError;

  int checkCalls = 0;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    checkCalls++;
    if (checkError != null) throw checkError!;
    return current;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _changes.stream;

  Future<void> dispose() => _changes.close();
}

void main() {
  late _FakeConnectivityPlatform platform;
  late ConnectivityPlatform original;

  setUp(() {
    original = ConnectivityPlatform.instance;
    platform = _FakeConnectivityPlatform();
    ConnectivityPlatform.instance = platform;
  });

  tearDown(() async {
    ConnectivityPlatform.instance = original;
    await platform.dispose();
  });

  group('the platform answer', () {
    test('starts out unanswered rather than negative', () async {
      // An unanswered question is not a lost network, and the offline banner is
      // better a moment late than wrong -- so a store reading this before the
      // platform has spoken must not read `false`.
      final source = PlatformConnectionSource();

      expect(source.isConnected, isNull);
      expect(source.hasConnection, isTrue);
    });

    test('reports what the platform says on the first listen', () async {
      platform.current = const [ConnectivityResult.wifi];
      final source = PlatformConnectionSource();

      final first = await source.watch().first;

      expect(first, isTrue);
      expect(source.isConnected, isTrue);
    });

    test('follows the network coming and going', () async {
      final source = PlatformConnectionSource();
      final seen = <bool>[];
      final done = Completer<void>();
      source.watch().listen((value) {
        seen.add(value);
        if (seen.length == 3) done.complete();
      });
      await pumpEventQueue();

      platform._changes.add(const [ConnectivityResult.wifi]);
      await pumpEventQueue();
      platform._changes.add(const [ConnectivityResult.none]);
      await pumpEventQueue();
      platform._changes.add(const [ConnectivityResult.mobile]);
      await done.future;

      expect(seen, [true, false, true]);
    });

    test('treats any transport other than none as connected', () async {
      // A USB tether or a VPN shows up as `none` on some devices and as `wifi` on
      // others, so the only value that may mean "no route" is `none` itself.
      for (final result in [
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
        ConnectivityResult.ethernet,
        ConnectivityResult.vpn,
        ConnectivityResult.bluetooth,
        ConnectivityResult.other,
      ]) {
        platform.current = [result];
        final source = PlatformConnectionSource();

        expect(await source.watch().first, isTrue, reason: '$result');
      }
    });

    test('treats an empty answer as no route', () async {
      platform.current = const [ConnectivityResult.none];

      expect(
        await PlatformConnectionSource().watch().first,
        isFalse,
        reason: 'a device that reports nothing attached has no route',
      );
    });

    test('does not repeat an answer it has already given', () async {
      // The source's contract is that a listener hears the current answer then
      // every *change*, so a steady connection stays quiet.
      final source = PlatformConnectionSource();
      final seen = <bool>[];
      source.watch().listen(seen.add);
      await pumpEventQueue();
      expect(seen, [true]);

      platform._changes.add(const [ConnectivityResult.wifi]);
      platform._changes.add(const [ConnectivityResult.wifi]);
      await pumpEventQueue();

      expect(seen, [true]);
    });

    test('a platform that will not answer is not a lost connection', () async {
      // No answer is not a negative answer. Reporting `false` here would put the
      // offline banner up for a device that is merely not talking, and the
      // connection coming back would not be what took it down.
      platform.checkError = StateError('channel unavailable');
      final source = PlatformConnectionSource();

      final events = <bool>[];
      source.watch().listen(events.add);
      await pumpEventQueue();

      expect(platform.checkCalls, 1);
      expect(source.isConnected, isNull);
      expect(source.hasConnection, isTrue);
      expect(events, isEmpty);
    });

    test('an error on the change stream is ignored', () async {
      final source = PlatformConnectionSource();
      final seen = <bool>[];
      source.watch().listen(seen.add);
      await pumpEventQueue();

      platform._changes.addError(StateError('channel closed'));
      platform._changes.add(const [ConnectivityResult.none]);
      await pumpEventQueue();

      expect(source.isConnected, isFalse, reason: 'the real answer still lands');
      expect(seen, [true, false]);
    });

    test('subscribes to the platform once however many listeners there are', () async {
      final source = PlatformConnectionSource();
      source.watch().listen((_) {});
      source.watch().listen((_) {});
      source.watch().listen((_) {});
      await pumpEventQueue();

      // One subscription for the life of the process: re-subscribing per caller
      // would mean a change arriving while nobody is listening being missed, and
      // the next listener starting from a value that no longer holds.
      expect(platform.checkCalls, 1);
    });

    test('hands a late listener the answer rather than making it wait', () async {
      // The bug this pins: `onCancel` cancels the platform subscription, so
      // while nobody is listening the source goes deaf. A listener joining later
      // used to re-run `onListen`, find the refresh unchanged, and sit on a
      // stream that only carried changes -- waiting on a network event that
      // might never come, which is the one case the banner has to be right
      // about.
      final source = PlatformConnectionSource();
      final held = source.watch().listen((_) {});
      await pumpEventQueue();
      platform._changes.add(const [ConnectivityResult.none]);
      await pumpEventQueue();
      expect(source.isConnected, isFalse);

      await held.cancel();

      final late = await source.watch().first.timeout(
        const Duration(seconds: 2),
      );

      expect(late, isFalse);
    });

    test('stops following the platform once nobody is listening', () async {
      // The counterpart to the above, and deliberate: the platform subscription
      // is torn down rather than left open, so a source nothing is watching does
      // not keep a channel alive for the life of the process.
      final source = PlatformConnectionSource();
      final held = source.watch().listen((_) {});
      await pumpEventQueue();
      expect(platform.checkCalls, 1);

      await held.cancel();
      await pumpEventQueue();

      platform._changes.add(const [ConnectivityResult.none]);
      await pumpEventQueue();

      expect(source.isConnected, isTrue, reason: 'nobody asked, nobody hears');
    });
  });
}