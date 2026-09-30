import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  Stream<UserModel?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(
      (user) => user != null ? UserModel.fromFirebase(user) : null,
    );
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return UserModel.fromFirebase(_requireUser(credential, 'sign in'));
  }

  @override
  Future<UserModel> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Keep operating on the same User instance we just created. Reading
    // _firebaseAuth.currentUser here could hand back a different object.
    final user = _requireUser(credential, 'sign up');
    await user.updateDisplayName(name);
    await user.reload();

    return UserModel.fromFirebase(user);
  }

  @override
  Future<UserModel?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    // null means the user dismissed the account chooser, which is not an error.
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    return UserModel.fromFirebase(_requireUser(userCredential, 'Google sign-in'));
  }

  @override
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    return user != null ? UserModel.fromFirebase(user) : null;
  }

  @override
  Future<UserModel?> refreshUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    try {
      await user.reload();
      await user.getIdToken(true);
      return UserModel.fromFirebase(user);
    } on FirebaseAuthException {
      // Revoked or expired account: drop the stale session.
      await _firebaseAuth.signOut();
      return null;
    } catch (_) {
      // Offline, platform channel failure, etc. Keep the cached session rather
      // than signing the user out; the caller decides how to surface this.
      return UserModel.fromFirebase(user);
    }
  }

  User _requireUser(UserCredential credential, String action) {
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase returned no user for $action.');
    }
    return user;
  }
}
