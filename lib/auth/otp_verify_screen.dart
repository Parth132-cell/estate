import 'package:estatex_app/navigation/main_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final otpCtrl = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: "Enter OTP",
                border: OutlineInputBorder(),
                counterText: "",
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (otpCtrl.text.trim().length != 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Enter valid 6-digit OTP"),
                            ),
                          );
                          return;
                        }

                        setState(() => loading = true);

                        bool success = false;

                        try {
                          success = await ref
                              .read(authControllerProvider.notifier)
                              .verifyOtp(otpCtrl.text.trim())
                              .timeout(const Duration(seconds: 60));
                        } catch (e) {
                          print("Verify timeout/error: $e");
                          success = false;
                        }

                        if (!mounted) return;

                        setState(() => loading = false);

                        if (success) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MainNavigation(),
                            ),
                            (_) => false,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Verification failed. Try again."),
                            ),
                          );
                        }
                      },
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Verify"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
