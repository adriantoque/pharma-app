import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

/// Outcome of the Firebase bootstrap attempt.
class FirebaseBootstrapResult {
  const FirebaseBootstrapResult.success()
    : errorMessage = null,
      isUnsupportedPlatform = false;

  const FirebaseBootstrapResult.failure(
    this.errorMessage, {
    this.isUnsupportedPlatform = false,
  });

  final String? errorMessage;
  final bool isUnsupportedPlatform;

  bool get isSuccess => errorMessage == null;
}

/// Initialises Firebase without ever throwing, so a bad or missing
/// configuration surfaces a readable screen instead of a black screen.
abstract final class FirebaseBootstrap {
  static Future<FirebaseBootstrapResult> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _enableOfflineCache();
      return const FirebaseBootstrapResult.success();
    } on UnsupportedError catch (e) {
      return FirebaseBootstrapResult.failure(
        e.message ?? 'Firebase is not configured for this platform.',
        isUnsupportedPlatform: true,
      );
    } catch (e) {
      return FirebaseBootstrapResult.failure(_describe(e));
    }
  }

  static String _describe(Object error) {
    final text = error.toString();
    return text
        .replaceFirst(RegExp(r'^(Exception|Bad state|Unsupported error):\s*'), '')
        .trim();
  }

  /// Puts Firestore's cache on disk, so a device that loses its connection keeps
  /// working rather than going blank.
  ///
  /// Android and iOS already default to a disk-backed cache, but the entire
  /// offline story rests on this one setting and it is not the sort of default
  /// that should be left to an SDK bump. Said out loud here instead, once.
  ///
  /// Part of bootstrap rather than something a provider arranges on demand,
  /// because the settings are ignored once the first query has gone out -- and
  /// `main.dart` builds a `FirebaseFirestore` provider as soon as this resolves.
  static void _enableOfflineCache() {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      // Considerably more than the catalogue needs: the seed is 490 lines, a few
      // hundred kilobytes, so the LRU threshold never comes near it and a device
      // that has been offline for days still finds its price list on disk.
      // Bounded anyway, because this is a cache and an unbounded one on a cheap
      // counter tablet is a slow way to run out of storage.
      cacheSizeBytes: 16 * 1024 * 1024,
    );
  }
}
