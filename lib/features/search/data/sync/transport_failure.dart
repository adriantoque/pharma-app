import 'package:firebase_core/firebase_core.dart' show FirebaseException;

/// Whether [error] means the request could not be delivered, as opposed to the
/// server having received it and said no.
///
/// The distinction decides what the app does next, so it is worth being precise
/// about. A transport failure is worth retrying: the write is still correct and
/// the connection will come back. A refusal is not: security rules denied it, the
/// database is not there, the field is the wrong type. Retrying a refusal
/// forever would fill the queue with something that can never land, and treating
/// a refusal as a lost connection would promise a pharmacist a fix that the
/// signal coming back will not bring.
///
/// Firestore's own codes are matched first, because those are a real enumeration
/// rather than a guess. Everything else is sniffed, because a lost connection
/// reaches Dart through several unrelated doors -- a `PlatformException` from the
/// native socket layer, a `TimeoutException`, an error message from a platform
/// that never became a `FirebaseException` at all -- and the codes only cover the
/// one door.
bool isTransportFailure(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      // gRPC's canonical "try again", and what the native clients report when the
      // socket is gone.
      'unavailable' || 'deadline-exceeded' || 'network-request-failed' => true,
      _ => _smellsLikeTransport(error),
    };
  }
  return _smellsLikeTransport(error);
}

/// Last resort: the message itself.
///
/// Deliberately narrower than a bare `error is SocketException`, which would need
/// a `dart:io` import this file does not have and would not match the Android and
/// web error strings anyway. All lowercase, because these arrive capitalised from
/// some layers and not others.
bool _smellsLikeTransport(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('timed out') ||
      text.contains('timeout');
}