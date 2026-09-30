import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  // Display (App title, splash) - 40px ExtraBold
  static TextStyle get display => GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w800, // ExtraBold
        color: AppColors.textPrimary,
        height: 1.1,
      );

  // H1 (Screen headings) - 28px Bold
  static TextStyle get h1 => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700, // Bold
        color: AppColors.textPrimary,
        height: 1.2,
      );

  // H2 (Section titles) - 20px SemiBold
  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600, // SemiBold
        color: AppColors.textPrimary,
        height: 1.3,
      );

  // Body (Content, descriptions) - 16px Regular
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400, // Regular
        color: AppColors.textPrimary,
        height: 1.5,
      );
      
  // Body Medium - 16px Medium (For buttons, inputs)
  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500, // Medium
        color: AppColors.textPrimary,
        height: 1.5,
      );

  // Caption (Labels, badges, muted info) - 12px Medium
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500, // Medium
        color: AppColors.textMuted,
        height: 1.4,
      );
}
