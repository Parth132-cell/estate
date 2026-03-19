import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/auth/auth_service.dart';
import 'package:estatex_app/auth/auth_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStep { phoneInput, otpInput, authenticated }

class AuthUiState {
  const AuthUiState({
    this.user,
    this.countryCode = '+1',
    this.phoneNumber = '',
    this.otpCode = '',
    this.verificationId,
    this.resendToken,
    this.resendInSeconds = 0,
    this.step = AuthStep.phoneInput,
    this.isLoading = false,
    this.errorMessage,
  });

  final AppUser? user;
  final String countryCode;
  final String phoneNumber;
  final String otpCode;
  final String? verificationId;
  final int? resendToken;
  final int resendInSeconds;
  final AuthStep step;
  final bool isLoading;
  final String? errorMessage;

  bool get canResend => resendInSeconds <= 0;
  String get e164Phone => '$countryCode$phoneNumber';

  AuthUiState copyWith({
    AppUser? user,
    String? countryCode,
    String? phoneNumber,
    String? otpCode,
    String? verificationId,
    int? resendToken,
    int? resendInSeconds,
    AuthStep? step,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthUiState(
      user: user ?? this.user,
      countryCode: countryCode ?? this.countryCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      otpCode: otpCode ?? this.otpCode,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      resendInSeconds: resendInSeconds ?? this.resendInSeconds,
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final authServiceProvider = Provider<AuthGateway>((ref) => AuthService());

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthUiState>((ref) {
      final controller = AuthController(
        authService: ref.watch(authServiceProvider),
        db: FirebaseFirestore.instance,
      );
      controller.bindAuthState();
      ref.onDispose(controller.dispose);
      return controller;
    });

class AuthController extends StateNotifier<AuthUiState> {
  AuthController({required AuthGateway authService, required FirebaseFirestore db})
      : _authService = authService,
        _db = db,
        super(const AuthUiState());

  final AuthGateway _authService;
  final FirebaseFirestore _db;

  StreamSubscription<User?>? _authSub;
  Timer? _resendTimer;

  void bindAuthState() {
    _authSub ??= _authService.authStateChanges().listen((user) async {
      if (user == null) {
        state = state.copyWith(user: null, step: AuthStep.phoneInput);
        return;
      }

      final profile = await _ensureUserProfile(user);
      state = state.copyWith(
        user: profile,
        step: AuthStep.authenticated,
        isLoading: false,
        clearError: true,
      );
    });
  }

  void updateCountryCode(String code) {
    state = state.copyWith(countryCode: code, clearError: true);
  }

  void updatePhone(String phone) {
    final sanitized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    state = state.copyWith(phoneNumber: sanitized, clearError: true);
  }

  void updateOtp(String otp) {
    final sanitized = otp.replaceAll(RegExp(r'[^0-9]'), '');
    state = state.copyWith(otpCode: sanitized, clearError: true);
  }

  Future<bool> sendOtp() async {
    if (state.phoneNumber.length < 8) {
      state = state.copyWith(errorMessage: 'Enter a valid phone number.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final session = await _authService.sendOtp(phoneNumber: state.e164Phone);
      _startResendTimer();
      state = state.copyWith(
        verificationId: session.verificationId,
        resendToken: session.resendToken,
        step: AuthStep.otpInput,
        isLoading: false,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(e),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network issue. Please try again.',
      );
      return false;
    }
  }

  Future<bool> resendOtp() async {
    if (!state.canResend || state.phoneNumber.isEmpty) {
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final session = await _authService.sendOtp(
        phoneNumber: state.e164Phone,
        forceResendingToken: state.resendToken,
      );
      _startResendTimer();
      state = state.copyWith(
        verificationId: session.verificationId,
        resendToken: session.resendToken,
        isLoading: false,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(e),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to resend OTP. Check your connection.',
      );
      return false;
    }
  }

  Future<bool> verifyOtp() async {
    if (state.verificationId == null || state.otpCode.length != 6) {
      state = state.copyWith(errorMessage: 'Enter a valid 6-digit OTP.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _authService.verifyOtp(
        verificationId: state.verificationId!,
        otp: state.otpCode,
      );

      if (result.user == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Session expired. Please request OTP again.',
        );
        return false;
      }

      await _ensureUserProfile(result.user!);

      state = state.copyWith(
        isLoading: false,
        step: AuthStep.authenticated,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(e),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to verify OTP. Please try again.',
      );
      return false;
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check and retry.';
      case 'session-expired':
        return 'OTP expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please retry.';
      case 'invalid-phone-number':
        return 'Invalid phone number format.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  Future<AppUser> _ensureUserProfile(User user) async {
    final userRef = _db.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'phone': user.phoneNumber,
        'profileType': 'individual',
        'canUploadProperty': true,
        'canHostLiveTour': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final fresh = await userRef.get();
    return AppUser.fromMap(user.uid, fresh.data());
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    state = state.copyWith(resendInSeconds: 30);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.resendInSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        state = state.copyWith(resendInSeconds: 0);
        return;
      }
      state = state.copyWith(resendInSeconds: next);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }
}
