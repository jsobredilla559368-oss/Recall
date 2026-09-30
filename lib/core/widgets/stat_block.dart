import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class StatBlock extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const StatBlock({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.h1.copyWith(
              color: valueColor ?? AppColors.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
