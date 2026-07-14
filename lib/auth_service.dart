import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  String? _userRole;
  String? get userRole => _userRole;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _fetchUserRole(user.uid);
      } else {
        _userRole = null;
        notifyListeners();
      }
    });
  }

  Future<void> _fetchUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        _userRole = doc.get('role');
      } else {
        _userRole = null;
      }
      notifyListeners();
    } catch (e) {
      _userRole = null;
      notifyListeners();
    }
  }

  Future<String?> signUpWithEmailAndPassword(
    String email,
    String password,
    String role,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });

        _userRole = role;
        notifyListeners();
        return null;
      }
      return 'Registration failed: Unknown error.';
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'An unknown Firebase error occurred.';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        await _fetchUserRole(user.uid);
        return null;
      }
      return 'Login failed: Unknown error.';
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'An unknown Firebase error occurred.';
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _userRole = null;
    notifyListeners();
  }
}
