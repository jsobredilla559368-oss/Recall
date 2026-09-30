import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum RecallButtonVariant { primary, secondary, ghost, google }

class RecallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final RecallButtonVariant variant;
  final IconData? icon;

  const RecallButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = RecallButtonVariant.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    switch (variant) {
      case RecallButtonVariant.primary:
        final primary = Theme.of(context).colorScheme.primary;
        final secondary = Theme.of(context).colorScheme.secondary;
        final gradient = isEnabled
            ? LinearGradient(
                colors: [primary, secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null;

        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: isEnabled ? null : AppColors.surface,
            gradient: gradient,
            borderRadius: BorderRadius.circular(50),
            border: isEnabled ? null : Border.all(color: AppColors.textMuted.withValues(alpha: 0.15)),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: isEnabled ? AppColors.background : AppColors.textMuted,
              disabledForegroundColor: AppColors.textMuted,
              disabledBackgroundColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: _buildChild(isEnabled ? AppColors.background : AppColors.textMuted),
          ),
        );

      case RecallButtonVariant.secondary:
        final primary = Theme.of(context).colorScheme.primary;
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: BorderSide(color: primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: _buildChild(primary),
          ),
        );

      case RecallButtonVariant.ghost:
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          child: _buildChild(AppColors.textMuted),
        );

      case RecallButtonVariant.google:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.background,
              side: const BorderSide(color: Colors.transparent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // In a real app we might use an SVG for the Google G logo
                // Here we use a generic icon for placeholder or text
                const Icon(Icons.g_mobiledata, size: 32, color: AppColors.background),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.background),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildChild(Color textColor) {
    if (icon == null) {
      return Text(
        label,
        style: AppTypography.bodyMedium.copyWith(color: textColor, fontWeight: FontWeight.w700),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: textColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(color: textColor, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
