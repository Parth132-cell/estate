import 'package:estatex_app/auth/auth_controller.dart';
import 'package:estatex_app/auth/otp_verify_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PhoneLoginScreen extends ConsumerWidget {
  const PhoneLoginScreen({super.key});

  static const _countryCodes = ['+1', '+44', '+61', '+91'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    ref.listen(authControllerProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Secure login',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your phone number to receive a one-time passcode.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  DropdownButton<String>(
                    value: state.countryCode,
                    items: _countryCodes
                        .map((code) => DropdownMenuItem(value: code, child: Text(code)))
                        .toList(),
                    onChanged: state.isLoading
                        ? null
                        : (code) {
                            if (code != null) {
                              controller.updateCountryCode(code);
                            }
                          },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.phone,
                      enabled: !state.isLoading,
                      onChanged: controller.updatePhone,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Phone number',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          final success = await controller.sendOtp();
                          if (!context.mounted || !success) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const OtpVerifyScreen()),
                          );
                        },
                  child: state.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Send OTP'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
