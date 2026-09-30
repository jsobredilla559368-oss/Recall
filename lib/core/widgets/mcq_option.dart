import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum MCQOptionState { idle, selected, correct, incorrect }

class MCQOption extends StatelessWidget {
  final String letter;
  final String text;
  final MCQOptionState state;
  final VoidCallback onTap;

  const MCQOption({
    super.key,
    required this.letter,
    required this.text,
    this.state = MCQOptionState.idle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    Color letterBgColor;
    Color letterTextColor;

    switch (state) {
      case MCQOptionState.idle:
        bgColor = AppColors.surface;
        borderColor = AppColors.surface;
        textColor = AppColors.textPrimary;
        letterBgColor = AppColors.background;
        letterTextColor = AppColors.textMuted;
        break;
      case MCQOptionState.selected:
        bgColor = AppColors.accent;
        borderColor = AppColors.accent;
        textColor = AppColors.background;
        letterBgColor = AppColors.background.withValues(alpha: 0.2);
        letterTextColor = AppColors.background;
        break;
      case MCQOptionState.correct:
        bgColor = AppColors.success;
        borderColor = AppColors.success;
        textColor = AppColors.background;
        letterBgColor = AppColors.background.withValues(alpha: 0.2);
        letterTextColor = AppColors.background;
        break;
      case MCQOptionState.incorrect:
        bgColor = AppColors.surface;
        borderColor = AppColors.error;
        textColor = AppColors.error;
        letterBgColor = AppColors.error.withValues(alpha: 0.15);
        letterTextColor = AppColors.error;
        break;
    }

    return GestureDetector(
      onTap: state == MCQOptionState.idle ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: letterBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  letter,
                  style: AppTypography.caption.copyWith(
                    color: letterTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: AppTypography.bodyMedium.copyWith(color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
