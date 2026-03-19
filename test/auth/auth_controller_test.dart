import 'dart:async';

import 'package:estatex_app/auth/auth_controller.dart';
import 'package:estatex_app/auth/auth_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthGateway implements AuthGateway {
  final _authController = StreamController<User?>.broadcast();
  OtpSession session = const OtpSession(verificationId: 'vid-1', resendToken: 123);

  @override
  Stream<User?> authStateChanges() => _authController.stream;

  @override
  Future<OtpSession> sendOtp({
    required String phoneNumber,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    return session;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<UserCredential> verifyOtp({required String verificationId, required String otp}) {
    throw UnimplementedError();
  }
}

void main() {
  test('sendOtp transitions to otp step and starts resend timer', () async {
    final gateway = _FakeAuthGateway();
    final controller = AuthController(
      authService: gateway,
      db: FakeFirebaseFirestore(),
    );

    controller.updateCountryCode('+91');
    controller.updatePhone('9876543210');

    final result = await controller.sendOtp();

    expect(result, isTrue);
    expect(controller.state.step, AuthStep.otpInput);
    expect(controller.state.verificationId, 'vid-1');
    expect(controller.state.resendInSeconds, 30);

    controller.dispose();
  });

  test('sendOtp validates bad phone input', () async {
    final gateway = _FakeAuthGateway();
    final controller = AuthController(
      authService: gateway,
      db: FakeFirebaseFirestore(),
    );

    controller.updatePhone('123');
    final result = await controller.sendOtp();

    expect(result, isFalse);
    expect(controller.state.errorMessage, isNotNull);

    controller.dispose();
  });
}
