import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF4C6FFF);
  static const Color primaryDark = Color(0xFF3B5BFF);
  static const Color primaryLight = Color(0xFF7B8FFF);
  
  // Background Colors
  static const Color background = Color(0xFFF8F9FA);
  // Page background to match modern light style
  static const Color page = Color(0xFFF6F7FA);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  // Neutral ink tones for chips/meta
  static const Color ink200 = Color(0xFFE2E8F0);
  static const Color ink400 = Color(0xFF94A3B8);
  static const Color ink500 = Color(0xFF64748B);
  static const Color ink700 = Color(0xFF334155);
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  
  // Neutral Colors
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);
  
  // Job Tags Colors
  static const Color remoteTag = Color(0xFF10B981);
  static const Color internshipTag = Color(0xFF3B82F6);
  static const Color fulltimeTag = Color(0xFF8B5CF6);
  
  // Additional Colors
  static const Color border = Color(0xFFE5E7EB);
  static const Color onPrimary = Colors.white;
  static const Color info = Color(0xFF3B82F6);

  // Light blue surface gradient used in headers/sections
  static const Gradient blueSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEAF4FF), Color(0xFFD3E9FF)],
  );
}
