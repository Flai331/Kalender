import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color accent = Color(0xFF03DAC6);

  // Background (Dark)
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color card = Color(0xFF2A2A2A);
  static const Color cardElevated = Color(0xFF333333);
  static const Color divider = Color(0xFF3A3A3A);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCCCCCC);
  static const Color textDisabled = Color(0xFF9E9E9E);

  // Event-Kategorien
  static const Color work = Color(0xFF448AFF);
  static const Color sport = Color(0xFF69F0AE);
  static const Color vacation = Color(0xFFFFD740);
  static const Color personal = Color(0xFFFF6D00);

  // Status
  static const Color started = Color(0xFF69F0AE);
  static const Color paused = Color(0xFFFFD740);
  static const Color done = Color(0xFF757575);
  static const Color fixedTag = Color(0xFFFF5252);
  static const Color flexible = Color(0xFF6C63FF);

  // Methode: Kategorie → Farbe
  static Color forCategory(String category) {
    switch (category) {
      case 'work':
        return work;
      case 'sport':
        return sport;
      case 'vacation':
        return vacation;
      default:
        return personal;
    }
  }
}
