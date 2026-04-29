import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AppUser?> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user == null) return null;
    return _getUserFromFirestore(credential.user!.uid);
  }

  Future<AppUser?> registerWithEmail(
      String email, String password, String name) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user == null) return null;

    final user = AppUser(
      uid: credential.user!.uid,
      displayName: name,
      email: email,
    );

    await _firestore.collection('users').doc(user.uid).set(user.toJson());
    return user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<AppUser?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return _getUserFromFirestore(firebaseUser.uid);
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<AppUser?> _getUserFromFirestore(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      // Create user doc if it doesn't exist (first login)
      final firebaseUser = _auth.currentUser!;
      final user = AppUser(
        uid: uid,
        displayName: firebaseUser.displayName ?? '',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL,
      );
      await _firestore.collection('users').doc(uid).set(user.toJson());
      return user;
    }
    return AppUser.fromJson(doc.data()!);
  }

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name);
    await _firestore.collection('users').doc(user.uid).update({
      'displayName': name,
    });
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
