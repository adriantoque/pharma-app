import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/store_settings_model.dart';

/// Reads and writes the store's one settings document.
///
/// Abstract so the settings screen can be built against a fake in a widget
/// test without a Firestore instance behind it -- the same shape the audit,
/// user and medicine repositories use. One document, not a stream of them:
/// there is exactly one store per install.
abstract class StoreSettingsRepository {
  /// The settings as they are right now, kept live.
  ///
  /// Yields null when no document has been saved yet, which is the normal
  /// state of a fresh install: the app runs on the model's defaults and the
  /// screen shows them, with the first save creating the document.
  Stream<StoreSettingsModel?> watch();

  /// Writes the whole settings document.
  ///
  /// A whole-document write rather than a field merge because settings are
  /// one thing: an editor saves a validated copy, never a fragment. Last
  /// writer wins, which is the accepted trade for a singleton document --
  /// the audit log records who wrote what, so a clobbered save is at least
  /// traceable.
  Future<void> save(StoreSettingsModel settings);
}

/// The Firestore-backed settings.
///
/// Firestore's own offline cache and write queue serve this document the same
/// way they serve the price list: an admin can edit while the network is gone
/// and the write rides out with the rest.
class FirestoreStoreSettingsRepository implements StoreSettingsRepository {
  FirestoreStoreSettingsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// `settings/store`. A singleton document with a fixed id, matched by the
  /// security rule that lets only an administrator write it.
  DocumentReference<Map<String, dynamic>> get _document =>
      _firestore.collection('settings').doc('store');

  @override
  Stream<StoreSettingsModel?> watch() {
    return _document.snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return StoreSettingsModel.fromMap(snapshot.data()!);
    });
  }

  @override
  Future<void> save(StoreSettingsModel settings) {
    // `updatedAt` is stamped here, server-side, rather than by the model:
    // the writer's clock and the server's can disagree, and the log should
    // read in one time. The model's map deliberately omits the field.
    return _document.set(
      {...settings.toMap(), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}

/// An in-memory settings store for tests: the same contract, no Firestore.
///
/// Save completes immediately, and every listener sees the new value, so a
/// provider built on this behaves like the real one without an emulator.
class InMemoryStoreSettingsRepository implements StoreSettingsRepository {
  InMemoryStoreSettingsRepository({StoreSettingsModel? initial})
    : _value = initial;

  StoreSettingsModel? _value;

  /// What each `watch()` listener is fed from, once it is listening.
  final _updates = StreamController<StoreSettingsModel?>.broadcast();

  /// The value as the last save left it, for a test to assert on.
  StoreSettingsModel? get value => _value;

  @override
  Stream<StoreSettingsModel?> watch() {
    // A per-listener controller rather than `async* { yield _value; yield*
    // _updates.stream; }`: an async generator only subscribes to the feed a
    // microtask after it starts, and a save made in between would be dropped
    // -- a broadcast stream holds nothing for a listener that has not
    // attached yet. This one emits the stored value the moment it is
    // listened to, so no save can fall into that gap.
    late StreamController<StoreSettingsModel?> controller;
    late StreamSubscription<StoreSettingsModel?> subscription;
    controller = StreamController<StoreSettingsModel?>(
      onListen: () {
        controller.add(_value);
        subscription = _updates.stream.listen(controller.add);
      },
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
      onCancel: () => subscription.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> save(StoreSettingsModel settings) async {
    _value = settings;
    _updates.add(settings);
  }

  /// Closes the feed. Tests call this in their teardown; the app never
  /// builds this class.
  void dispose() {
    if (!_updates.isClosed) _updates.close();
  }
}
