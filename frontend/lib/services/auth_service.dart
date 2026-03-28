import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up with email and password
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
    required String surname,
    required BuildContext context,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name with the user's real name
      await userCredential.user?.updateDisplayName('$name $surname');
      return userCredential;
      
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during sign up.';
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for that email.';
      }
      _showError(context, errorMessage);
      return null;
    } catch (e) {
      _showError(context, 'Something went wrong. Please try again.');
      return null;
    }
  }

  // Log in with email and password
  Future<UserCredential?> login({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to log in.';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided.';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Invalid email or password.';
      }
      _showError(context, errorMessage);
      return null;
    } catch (e) {
      _showError(context, 'Something went wrong. Please try again.');
      return null;
    }
  }

  // Reset password
  Future<void> resetPassword({
    required String email,
    required BuildContext context,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset link sent! Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showError(context, e.message ?? 'Could not send reset email.');
    } catch (e) {
      _showError(context, 'Something went wrong.');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  void _showError(BuildContext context, String message) {    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
