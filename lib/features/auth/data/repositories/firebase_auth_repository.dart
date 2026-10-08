import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/auth_exception.dart';
import '../../domain/user_role.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

/// The real backend: Firebase Auth for credentials, Firestore for the profile
/// that carries the role.
///
/// Firebase Auth answers "who is this?". It does not answer "what may they
/// do?" -- that lives in `users/{uid}` and is read here on every sign-in and
/// refresh. Splitting the two is deliberate: a role change takes effect the
/// next time a session refreshes, without touching the account itself.
///
/// Firestore failures degrade rather than lock anybody out. A device that is
/// offline at sign-in still gets a session, with [UserRole.staff] as the
/// fallback; the correct role arrives on the next successful refresh.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  @override
  Stream<UserModel?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return await _enrich(user);
    });
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
    final user = _requireUser(credential, 'sign in');
    final enriched = await _enrich(user);

    // A deactivated account signs in successfully -- Firebase Auth knows
    // nothing about the flag -- and is signed back out here, before the
    // session reaches the app.
    if (!enriched.active) {
      await _firebaseAuth.signOut();
      throw const AuthException(
        'This account has been deactivated. Contact an administrator.',
      );
    }
    return enriched;
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

    // The profile document, without which this account would have no role.
    // Written with `merge` so a pre-existing document -- made by hand in the
    // console, say -- keeps anything it already carried.
    await _firestore.collection('users').doc(user.uid).set({
      'displayName': name,
      'email': email,
      'role': UserRole.staff.storageKey,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return _enrich(user);
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
    final user = _requireUser(userCredential, 'Google sign-in');

    // A first-time Google sign-in has no Firestore document. Create a staff
    // profile so the account has a role; a returning one keeps whatever it
    // had.
    final docRef = _firestore.collection('users').doc(user.uid);
    final existing = await docRef.get();
    if (!existing.exists) {
      await docRef.set({
        'displayName': user.displayName,
        'email': user.email,
        'role': UserRole.staff.storageKey,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final enriched = await _enrich(user);
    if (!enriched.active) {
      await _firebaseAuth.signOut();
      throw const AuthException(
        'This account has been deactivated. Contact an administrator.',
      );
    }
    return enriched;
  }

  @override
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return _enrich(user);
  }

  @override
  Future<UserModel?> refreshUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    try {
      await user.reload();
      await user.getIdToken(true);
      return await _enrich(user);
    } on FirebaseAuthException {
      // Revoked or expired account: drop the stale session.
      await _firebaseAuth.signOut();
      return null;
    } catch (_) {
      // Offline, platform channel failure, etc. Keep the cached session
      // rather than signing the user out; the caller decides how to surface
      // this.
      return await _enrich(user);
    }
  }

  /// Firebase Auth's view of [user], filled in by its Firestore profile.
  ///
  /// Any failure reading the document falls back to the Auth values alone,
  /// with the model's own defaults for role and active. That is not the same
  /// as "the user is deactivated" -- a read that did not happen is not a read
  /// that said no -- and the caller treats the resulting session as valid.
  Future<UserModel> _enrich(User user) async {
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return UserModel.fromFirestore(
        uid: user.uid,
        data: doc.data(),
        fallbackName: user.displayName,
        fallbackEmail: user.email,
      );
    } catch (_) {
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
