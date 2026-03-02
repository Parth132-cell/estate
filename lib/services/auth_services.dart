import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthServices {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<void> register(String email, String password, String role) async {
    try {
      // 1️⃣ Create user in Firebase Auth
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      // 2️⃣ Save user in Firestore
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'role': role,
        'approved': role == 'broker' ? false : true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔥 IMPORTANT LOG (for debugging)
      debugPrint("User saved in Firestore: $uid");
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Authentication failed";
    } catch (e) {
      throw "Firestore save failed";
    }
  }

  Future<User?> login(String email, String password) async {
    final res = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return res.user;
  }

  Future<DocumentSnapshot> getUser(String uid) {
    return _db.collection('users').doc(uid).get();
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
