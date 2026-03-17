import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // [NEW] Sign up with Email and Password
  Future<User?> signUp(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      print('Sign Up Error: ${e.code}');
      // Common codes: 'email-already-in-use', 'weak-password'
      return null;
    }
  }

  // Sign in with Email and Password
  Future<User?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      print('Auth Error: ${e.code}');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async => await _auth.signOut();

  // Get current user
  User? get currentUser => _auth.currentUser;
}