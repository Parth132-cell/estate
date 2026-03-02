import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF2563EB); // Blue
  static const primarySoft = Color(0xFFEFF4FF);

  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF8F9FB);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
}

class AppText {
  static const h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

  static const body = TextStyle(fontSize: 14, color: AppColors.textSecondary);

  static const label = TextStyle(fontSize: 12, color: AppColors.textSecondary);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppButtons {
  static final primary = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
