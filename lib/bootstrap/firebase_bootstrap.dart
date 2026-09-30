import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

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
}
