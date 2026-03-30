import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

final authProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final authActionsProvider = Provider<AuthActions>((ref) {
  return AuthActions();
});

class AuthActions {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signIn(String email, String password) async {
    // Sign in via FastAPI (JWT), then store token
    await ApiService().login(email, password);
    // Also sync with Firebase Auth for FCM
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await ApiService().logout();
    await _auth.signOut();
  }
}
