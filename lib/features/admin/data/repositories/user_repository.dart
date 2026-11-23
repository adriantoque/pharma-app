import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../auth/domain/auth_exception.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/data/models/user_model.dart';

/// Reads and writes the `users` collection, and manages the Firebase Auth
/// accounts behind it.
class UserRepository {
  UserRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users');

  Stream<List<UserModel>> watchAll() {
    return _collection.snapshots().map((snapshot) {
      final users = [
        for (final doc in snapshot.docs)
          UserModel.fromFirestore(uid: doc.id, data: doc.data()),
      ]..sort((a, b) {
          if (a.active != b.active) return a.active ? -1 : 1;
          final an = (a.name ?? '').toLowerCase();
          final bn = (b.name ?? '').toLowerCase();
          return an.compareTo(bn);
        });
      return List.unmodifiable(users);
    });
  }

  Future<UserModel> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final secondaryName =
        'admin-create-${DateTime.now().microsecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: secondaryName,
      options: Firebase.app().options,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(name);
      await credential.user!.reload();

      await _collection.doc(uid).set({
        'displayName': name,
        'email': email.trim(),
        'role': role.storageKey,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await secondaryAuth.signOut();

      return UserModel(
        id: uid,
        name: name,
        email: email.trim(),
        role: role,
        active: true,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_describeFirebaseError(e));
    } finally {
      try {
        await secondaryApp.delete();
      } catch (_) {}
    }
  }

  Future<void> updateUser({
    required String uid,
    String? name,
    UserRole? role,
  }) async {
    final fields = <String, dynamic>{
      'displayName': ?name,
      'role': ?role?.storageKey,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (fields.isEmpty) return;
    await _collection.doc(uid).update(fields);
  }

  Future<void> setActive(String uid, bool active) {
    return _collection.doc(uid).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_describeFirebaseError(e));
    }
  }

  static String _describeFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'weak-password':
        return 'The password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account is registered with that email.';
      case 'operation-not-allowed':
        return 'Signups are disabled in Firebase. Enable the Email/Password '
            'provider in the console.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}