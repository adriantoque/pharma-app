/// A sign-in or account operation that was refused for a reason the screen
/// can show to a user.
///
/// Distinct from a transport error so the provider can tell "wrong password"
/// (the user retypes it) from "the network is down" (the user tries again
/// later). `AuthProvider` already makes that distinction for Firebase's own
/// `FirebaseAuthException`; this is the same shape for everything else.
///
/// Moved out of the demo repository when the real one grew a reason to throw
/// it: a deactivated account is refused on sign-in, and both backends need to
/// agree on the type they refuse it with.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}