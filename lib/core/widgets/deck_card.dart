import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class DeckCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int totalCards;
  final String tag;
  final bool isFlashcard;
  final VoidCallback onTap;
  final VoidCallback? onAction;
  final String? actionLabel;
  final Color? actionColor;
  final bool isActionLoading;
  final int? dueCount;

  const DeckCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.totalCards,
    required this.tag,
    this.isFlashcard = false,
    required this.onTap,
    this.onAction,
    this.actionLabel,
    this.actionColor,
    this.isActionLoading = false,
    this.dueCount,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActionColor = actionColor ?? AppColors.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFlashcard ? AppColors.amber.withValues(alpha: 0.15) : AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    tag,
                    style: AppTypography.caption.copyWith(
                      color: isFlashcard ? AppColors.amber : AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (actionLabel != null)
                  GestureDetector(
                    onTap: isActionLoading ? null : onAction,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: effectiveActionColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: effectiveActionColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: isActionLoading
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: effectiveActionColor,
                              ),
                            )
                          : Text(
                              actionLabel!.toUpperCase(),
                              style: AppTypography.caption.copyWith(
                                color: effectiveActionColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  )
                else if (dueCount != null && dueCount! > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '$dueCount DUE',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$totalCards Cards',
                        style: AppTypography.caption,
                      ),
                    ],
                  )
                else
                  Text(
                    '$totalCards Cards',
                    style: AppTypography.caption,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.h2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
