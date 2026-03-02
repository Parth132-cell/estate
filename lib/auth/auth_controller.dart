// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_riverpod/legacy.dart';
// import 'auth_state.dart';

// final authProvider = StateProvider<AppUser?>((ref) => null);

// final authControllerProvider = Provider<AuthController>((ref) {
//   return AuthController(ref);
// });

// class AuthController {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _db = FirebaseFirestore.instance;
//   final Ref ref;

//   AuthController(this.ref);

//   String? _verificationId;
//   int? _resendToken;

//   /// SEND OTP
//   Future<void> sendOtp({
//     required String phone,
//     required Function(String error) onError,
//     required Function() onCodeSent,
//   }) async {
//     await _auth.verifyPhoneNumber(
//       phoneNumber: phone,
//       timeout: const Duration(seconds: 60),

//       verificationCompleted: (PhoneAuthCredential credential) async {
//         await _auth.signInWithCredential(credential);
//       },

//       verificationFailed: (FirebaseAuthException e) {
//         print("Send OTP Error: ${e.code} - ${e.message}");
//         onError(e.message ?? "Failed to send OTP");
//       },

//       codeSent: (String verificationId, int? resendToken) {
//         _verificationId = verificationId;
//         _resendToken = resendToken;
//         print("VerificationId stored");
//         onCodeSent();
//       },

//       codeAutoRetrievalTimeout: (String verificationId) {
//         _verificationId = verificationId;
//       },
//     );
//   }

//   /// VERIFY OTP
//   Future<bool> verifyOtp(String otp) async {
//     try {
//       if (_verificationId == null) {
//         print("VerificationId null");
//         return false;
//       }

//       final credential = PhoneAuthProvider.credential(
//         verificationId: _verificationId!,
//         smsCode: otp,
//       );

//       final result = await _auth.signInWithCredential(credential);
//       print("Result user: ${result.user?.uid}");
//       print("Current user: ${_auth.currentUser?.uid}");

//       final user = _auth.currentUser;
//       print("User after signIn: ${user?.uid}");

//       if (user == null) return false;

//       final userRef = _db.collection('users').doc(user.uid);
//       final doc = await userRef.get();

//       // Create profile if not exists
//       if (!doc.exists) {
//         await userRef.set({
//           'phone': user.phoneNumber,
//           'profileType': 'individual',
//           'kycStatus': 'not_submitted',
//           'isVerified': false,
//           'createdAt': FieldValue.serverTimestamp(),
//         });
//       }

//       final userData = await userRef.get();

//       ref.read(authProvider.notifier).state = AppUser.fromMap(
//         user.uid,
//         userData.data(),
//       );

//       return true;
//     } catch (e) {
//       print("Verify OTP Error: $e");
//       return false;
//     }
//   }

//   /// Load user on app start
//   Future<void> loadUserIfLoggedIn() async {
//     final user = _auth.currentUser;
//     if (user == null) return;

//     final doc = await _db.collection('users').doc(user.uid).get();
//     if (!doc.exists) return;

//     ref.read(authProvider.notifier).state = AppUser.fromMap(
//       user.uid,
//       doc.data(),
//     );
//   }

//   /// Logout
//   Future<void> logout() async {
//     await _auth.signOut();
//     ref.read(authProvider.notifier).state = null;
//   }
// }
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'auth_state.dart'; // Your AppUser model

// State class to hold auth status and verification ID
class AuthState {
  final AppUser? user;
  final String? verificationId;
  AuthState({this.user, this.verificationId});
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref);
  },
);

class AuthController extends StateNotifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Ref ref;

  AuthController(this.ref) : super(AuthState());

  /// SEND OTP
  Future<void> sendOtp({
    required String phone,
    required Function(String error) onError,
    required Function() onCodeSent,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (Android only)
          await _auth.signInWithCredential(credential);
          await _syncUser();
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? "Verification failed");
        },
        codeSent: (String verificationId, int? resendToken) {
          // Save verificationId in state so it's not lost
          state = AuthState(user: state.user, verificationId: verificationId);
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          state = AuthState(user: state.user, verificationId: verificationId);
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  /// VERIFY OTP
  Future<bool> verifyOtp(String otp) async {
    try {
      if (state.verificationId == null) return false;

      final credential = PhoneAuthProvider.credential(
        verificationId: state.verificationId!,
        smsCode: otp,
      );

      // 1. Sign in
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user == null) return false;

      // 2. Wait a tiny bit for the Auth token to propagate to Firestore
      // This solves the "Permission Denied" race condition
      await Future.delayed(const Duration(milliseconds: 500));

      final userRef = _db.collection('users').doc(user.uid);

      // 3. Use a Try-Catch specifically for the Firestore call
      DocumentSnapshot doc;
      try {
        doc = await userRef.get();
      } catch (e) {
        print("Firestore Error: $e");
        // If Firestore fails but Auth succeeded, we might need to retry once
        doc = await userRef.get();
      }

      if (!doc.exists) {
        await userRef.set({
          'phone': user.phoneNumber,
          'profileType': 'individual',
          'kycStatus': 'not_submitted',
          'isVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 4. Update Riverpod State
      state = AuthState(
        user: AppUser.fromMap(user.uid, (await userRef.get()).data()),
        verificationId: state.verificationId,
      );

      return true;
    } catch (e) {
      print("Verify OTP Error: $e");
      return false;
    }
  }

  /// Sync Firestore User
  Future<void> _syncUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _db.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'phone': user.phoneNumber,
        'profileType': 'individual',
        'kycStatus': 'not_submitted',
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final freshDoc = await userRef.get();
    state = AuthState(
      user: AppUser.fromMap(user.uid, freshDoc.data()),
      verificationId: state.verificationId,
    );
  }

  // Call this on app start
  Future<void> loadUser() async {
    if (_auth.currentUser != null) {
      await _syncUser();
    }
  }
}
