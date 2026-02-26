import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (displayName.isNotEmpty) {
      await userCredential.user?.updateDisplayName(displayName);
    }
    final actionSettings = ActionCodeSettings(
      url: 'https://sefirot-ff9af.web.app',
      handleCodeInApp: false,
    );
    await userCredential.user?.sendEmailVerification(actionSettings);
    await _createUserDocIfNotExists(userCredential.user, displayName: displayName);
    return userCredential;
  }

  @override
  Future<UserCredential?> signInWithGoogle() async {
    UserCredential? userCredential;

    if (kIsWeb) {
      // On Web, use Firebase Auth's native popup — no google_sign_in package needed
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      userCredential = await _auth.signInWithPopup(provider);
    } else {
      // On mobile, use the google_sign_in package
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      userCredential = await _auth.signInWithCredential(credential);
    }

    await _createUserDocIfNotExists(userCredential.user);
    return userCredential;
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) await _googleSignIn.signOut();
    await _auth.signOut();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Creates the user document in Firestore if it does not already exist.
  /// This is called on both sign-up and first Google sign-in.
  Future<void> _createUserDocIfNotExists(User? user, {String displayName = ''}) async {
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      final name = displayName.isNotEmpty ? displayName : (user.displayName ?? '');
      await userDoc.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': name,
        'photoUrl': user.photoURL ?? '',
        'accountType': 'pilgrim',
        'bio': '',
        'interests': <String>[],
        'languages': <String>[],
        'events': <String>[],
        'nationality': '',
        'isOnboarded': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
