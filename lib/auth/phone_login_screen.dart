import 'dart:async';

import 'package:estatex_app/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  bool _otpSent = false;
  final _phoneCtrl = TextEditingController();
  String _countryCode = '+91';
  bool _sendingOtp = false;
  String? _phoneError;

  final List<TextEditingController> _otpCtrls = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());
  bool _verifying = false;
  String? _otpError;

  String? _verificationId;
  int? _resendToken;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _phoneError = 'Please enter your mobile number');
      return;
    }
    if (phone.length < 10) {
      setState(() => _phoneError = 'Please enter a valid 10-digit number');
      return;
    }
    if (_countryCode == '+91' && !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() => _phoneError = 'Please enter a valid Indian mobile number');
      return;
    }
    setState(() {
      _sendingOtp = true;
      _phoneError = null;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '$_countryCode$phone',
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        if (!mounted) return;
        setState(() => _verifying = true);
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _otpError = _friendlyError(e);
            _verifying = false;
          });
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _sendingOtp = false;
          _phoneError = _friendlyError(e);
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _otpSent = true;
          _sendingOtp = false;
        });
        _startTimer();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!mounted) return;
        setState(() => _verificationId = verificationId);
      },
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _otpError = 'Please enter the 6-digit OTP');
      return;
    }
    if (_verificationId == null) {
      setState(() => _otpError = 'Session expired. Please resend OTP.');
      return;
    }
    setState(() {
      _verifying = true;
      _otpError = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      for (final c in _otpCtrls) c.clear();
      _otpFocus.first.requestFocus();
      setState(() {
        _otpError = _friendlyError(e);
        _verifying = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _otpError = 'Something went wrong. Please try again.';
        _verifying = false;
      });
    }
  }

  void _startTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) t.cancel();
      });
    });
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;
    for (final c in _otpCtrls) c.clear();
    setState(() => _otpError = null);
    await _sendOtp();
  }

  String _friendlyError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'Invalid phone number. Please check and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a few minutes.';
        case 'invalid-verification-code':
          return 'Wrong OTP. Please check the SMS and try again.';
        case 'session-expired':
          return 'OTP expired. Please request a new one.';
        case 'quota-exceeded':
          return 'SMS limit reached. Please try again later.';
        case 'network-request-failed':
          return 'No internet connection. Please check your network.';
        case 'user-disabled':
          return 'This account has been disabled. Contact support.';
        default:
          return e.message ?? 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.home_work_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'EstateX',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Step indicator
              Row(
                children: [
                  _Dot(active: true, done: _otpSent, label: '1'),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: _otpSent
                          ? AppColors.primary
                          : Colors.grey.shade200,
                    ),
                  ),
                  _Dot(active: _otpSent, done: false, label: '2'),
                ],
              ),
              const SizedBox(height: 32),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _otpSent
                    ? _OtpStep(
                        key: const ValueKey('otp'),
                        phone: '$_countryCode${_phoneCtrl.text.trim()}',
                        controllers: _otpCtrls,
                        focusNodes: _otpFocus,
                        error: _otpError,
                        verifying: _verifying,
                        resendSeconds: _resendSeconds,
                        onVerify: _verifyOtp,
                        onResend: _resendOtp,
                        onChangeNumber: () => setState(() {
                          _otpSent = false;
                          _otpError = null;
                          for (final c in _otpCtrls) c.clear();
                        }),
                      )
                    : _PhoneStep(
                        key: const ValueKey('phone'),
                        controller: _phoneCtrl,
                        countryCode: _countryCode,
                        error: _phoneError,
                        sending: _sendingOtp,
                        onCountryCode: (c) => setState(() => _countryCode = c),
                        onSend: _sendOtp,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Phone Step ──────────────────────────────────────────────────────────────
class _PhoneStep extends StatelessWidget {
  final TextEditingController controller;
  final String countryCode;
  final String? error;
  final bool sending;
  final ValueChanged<String> onCountryCode;
  final VoidCallback onSend;

  const _PhoneStep({
    super.key,
    required this.controller,
    required this.countryCode,
    required this.error,
    required this.sending,
    required this.onCountryCode,
    required this.onSend,
  });

  static const _countries = [
    ('+91', 'India 🇮🇳'),
    ('+1', 'USA 🇺🇸'),
    ('+44', 'UK 🇬🇧'),
    ('+971', 'UAE 🇦🇪'),
    ('+65', 'Singapore 🇸🇬'),
    ('+61', 'Australia 🇦🇺'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter your mobile number',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "We'll send a one-time password to verify.",
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),

        Row(
          children: [
            // Country code
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Select country',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ..._countries.map(
                      (c) => ListTile(
                        title: Text('${c.$2}  ${c.$1}'),
                        onTap: () {
                          onCountryCode(c.$1);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      countryCode,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: const TextStyle(
                  fontSize: 18,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '98765 43210',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.normal,
                    letterSpacing: 0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ],
        ),

        if (error != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 14, color: Colors.red),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  error!,
                  style: const TextStyle(fontSize: 13, color: Colors.red),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: sending ? null : onSend,
            child: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Send OTP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "By continuing, you agree to EstateX's Terms of Service and Privacy Policy.",
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── OTP Step ─────────────────────────────────────────────────────────────────
class _OtpStep extends StatelessWidget {
  final String phone;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final String? error;
  final bool verifying;
  final int resendSeconds;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onChangeNumber;

  const _OtpStep({
    super.key,
    required this.phone,
    required this.controllers,
    required this.focusNodes,
    required this.error,
    required this.verifying,
    required this.resendSeconds,
    required this.onVerify,
    required this.onResend,
    required this.onChangeNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter OTP',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'We sent a 6-digit OTP to\n'),
              TextSpan(
                text: phone,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onChangeNumber,
          child: const Text(
            'Change number',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (i) => SizedBox(
              width: 46,
              child: TextField(
                controller: controllers[i],
                focusNode: focusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                autofocus: i == 0,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: controllers[i].text.isNotEmpty
                      ? AppColors.primarySoft
                      : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && i < 5) focusNodes[i + 1].requestFocus();
                  if (val.isEmpty && i > 0) focusNodes[i - 1].requestFocus();
                  final full = controllers.map((c) => c.text).join();
                  if (full.length == 6) onVerify();
                },
              ),
            ),
          ),
        ),

        if (error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: verifying ? null : onVerify,
            child: verifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Verify OTP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 20),

        Center(
          child: resendSeconds > 0
              ? Text(
                  'Resend OTP in ${resendSeconds}s',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                )
              : GestureDetector(
                  onTap: onResend,
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 14),
                      children: [
                        TextSpan(
                          text: "Didn't receive OTP? ",
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        TextSpan(
                          text: 'Resend',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Dot ──────────────────────────────────────────────────────────────────────
class _Dot extends StatelessWidget {
  final bool active;
  final bool done;
  final String label;
  const _Dot({required this.active, required this.done, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, color: Colors.white, size: 14)
            : Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : Colors.grey.shade400,
                ),
              ),
      ),
    );
  }
}
