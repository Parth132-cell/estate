import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class OtpSession {
  const OtpSession({
    required this.verificationId,
    required this.resendToken,
  });

  final String verificationId;
  final int? resendToken;
}

abstract class AuthGateway {
  Stream<User?> authStateChanges();
  Future<OtpSession> sendOtp({
    required String phoneNumber,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  });
  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String otp,
  });
  Future<void> signOut();
}

class AuthService implements AuthGateway {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  Future<OtpSession> sendOtp({
    required String phoneNumber,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final completer = Completer<OtpSession>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      forceResendingToken: forceResendingToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android auto-read / instant verification.
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException exception) {
        if (!completer.isCompleted) {
          completer.completeError(exception);
        }
      },
      codeSent: (verificationId, resendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            OtpSession(
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  @override
  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String otp,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    return _auth.signInWithCredential(credential);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
