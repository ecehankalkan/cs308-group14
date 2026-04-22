import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _baseUrl    = 'http://127.0.0.1:8000';
  static const String _keyAccess  = 'access_token';
  static const String _keyRefresh = 'refresh_token';

  // ---------------------------------------------------------------------------
  // Token helpers
  // ---------------------------------------------------------------------------

  static Future<void> _saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccess, access);
    await prefs.setString(_keyRefresh, refresh);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccess);
  }

  /// Returns headers with Bearer token for authenticated API calls.
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAccessToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ---------------------------------------------------------------------------
  // Sign up — Firebase auth + Django backend registration
  // ---------------------------------------------------------------------------

  static Future<Map<String, String>> _getBaseHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final cookieStr = prefs.getString('sessionid_cookie');
    final headers = {'Content-Type': 'application/json'};
    if (cookieStr != null && cookieStr.isNotEmpty) {
      final sessionId = cookieStr.replaceAll('sessionid=', '').trim();
      headers['X-Session-Id'] = sessionId;
      headers['Cookie'] = cookieStr;
    }
    return headers;
  }

  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
    required String surname,
    required String taxId,
    required String homeAddress,
    required BuildContext context,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user?.updateDisplayName('$name $surname');

      final headers = await _getBaseHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/register/'),
        headers: headers,
        body: jsonEncode({
          'email':        email,
          'password':     password,
          'name':         '$name $surname',
          'tax_id':       taxId,
          'home_address': homeAddress,
        }),
      );

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveTokens(body['access'] as String, body['refresh'] as String);
      } else {
        await userCredential.user?.delete(); // Revert firebase user creation
        if (!context.mounted) return null;
        _showError(context, 'Backend registration failed: ${response.statusCode} - ${response.body}');
        return null;
      }

      return userCredential;

    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during sign up.';
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for that email.';
      }
      if (!context.mounted) return null;
      _showError(context, errorMessage);
      return null;
    } catch (e) {
      if (!context.mounted) return null;
      _showError(context, 'Something went wrong. Please try again.');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Login — Firebase auth + Django JWT
  // ---------------------------------------------------------------------------

  Future<UserCredential?> login({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final headers = await _getBaseHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/login/'),
        headers: headers,
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveTokens(body['access'] as String, body['refresh'] as String);
      } else {
        await _auth.signOut(); // Revert firebase login
        if (!context.mounted) return null;
        _showError(context, 'Backend login failed. Invalid credentials or user not found.');
        return null;
      }

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
      if (!context.mounted) return null;
      _showError(context, errorMessage);
      return null;
    } catch (e) {
      if (!context.mounted) return null;
      _showError(context, 'Something went wrong. Please try again.');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Reset password
  // ---------------------------------------------------------------------------

  Future<void> resetPassword({
    required String email,
    required BuildContext context,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset link sent! Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      _showError(context, e.message ?? 'Could not send reset email.');
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Something went wrong.');
    }
  }

  // ---------------------------------------------------------------------------
  // Sign out — clear Firebase session and stored tokens
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
    await prefs.remove('sessionid_cookie'); // Ensure completely blank guest cart
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}