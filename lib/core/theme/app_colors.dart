import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class AppColors {
  // Primary Backgrounds
  static const Color background = Color(0xFF0D1B2A); // Deep navy
  static const Color surface = Color(0xFF142232); // Slightly lighter navy

  // Dynamic Accents linked to ThemeService
  static Color get accent => ThemeService.instance.primaryColor;
  static Color get secondaryAccent => ThemeService.instance.secondaryColor;
  static LinearGradient get gradient => ThemeService.instance.primaryGradient;
  static LinearGradient get auraGradient => ThemeService.instance.cardAuraGradient;

  // Constants & Defaults
  static const Color defaultAccent = Color(0xFF00E5C8); // Electric teal
  static const Color amber = Color(0xFFF5A623); // Streak / Achievement

  // Text
  static const Color textPrimary = Color(0xFFF0F4F8); // Off-white
  static const Color textMuted = Color(0xFF8AA0B8); // Muted blue-grey
  static const Color border = Color(0xFF2C3E50); // Subtle border

  // Semantic
  static const Color error = Color(0xFFFF6B6B); // Soft red
  static const Color success = Color(0xFF00C896); // Teal-green
}
