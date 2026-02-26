import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password});
  Future<UserCredential> createUserWithEmailAndPassword({required String email, required String password, String displayName = ''});
  Future<UserCredential?> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}
