import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'otp_verify_screen.dart';
import 'auth_controller.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final phoneCtrl = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your mobile number",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                prefixText: "+91 ",
                border: OutlineInputBorder(),
                hintText: "9876543210",
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
                        if (phoneCtrl.text.trim().length != 10) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Enter valid 10-digit number"),
                            ),
                          );
                          return;
                        }

                        setState(() => loading = true);

                        // ✅ Use Riverpod instance (IMPORTANT)
                        await ref
                            .read(authControllerProvider.notifier)
                            .sendOtp(
                              phone: "+91${phoneCtrl.text.trim()}",
                              onError: (error) {
                                setState(() => loading = false);
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(error)));
                              },
                              onCodeSent: () {
                                setState(() => loading = false);

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const OtpVerifyScreen(),
                                  ),
                                );
                              },
                            );
                      },
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Send OTP"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
