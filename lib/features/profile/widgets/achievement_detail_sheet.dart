import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/models/achievement_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'achievement_celebration_dialog.dart';

class AchievementDetailSheet extends StatelessWidget {
  final AchievementModel achievement;

  const AchievementDetailSheet({
    super.key,
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final isUnlocked = a.isUnlocked;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Large Emblem
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked
                  ? a.primaryColor.withValues(alpha: 0.15)
                  : AppColors.background,
              border: Border.all(
                color: isUnlocked
                    ? a.primaryColor
                    : AppColors.textMuted.withValues(alpha: 0.2),
                width: 2.5,
              ),
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                        color: a.primaryColor.withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Icon(
                a.icon,
                size: 38,
                color: isUnlocked ? a.primaryColor : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Badge Title
          Text(a.title, style: AppTypography.h1.copyWith(fontSize: 22)),
          const SizedBox(height: 4),

          // Tier Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: a.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              a.tierName.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: a.primaryColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            a.description,
            style: AppTypography.body.copyWith(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Progress Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textMuted.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Milestone Progress',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${a.currentCount} / ${a.targetCount} ${a.unit}',
                      style: AppTypography.caption.copyWith(
                        color: isUnlocked ? a.primaryColor : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: a.progress,
                    minHeight: 8,
                    backgroundColor: AppColors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isUnlocked ? a.primaryColor : AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // XP Reward Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.zap, size: 16, color: AppColors.amber),
                const SizedBox(width: 8),
                Text(
                  '+${a.xpReward} XP Reward',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Button
          if (isUnlocked)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: a.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.sparkles, size: 18),
                label: const Text(
                  'Replay Celebration',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) =>
                        AchievementCelebrationDialog(achievement: a),
                  );
                },
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  side: BorderSide(
                    color: AppColors.textMuted.withValues(alpha: 0.2),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
        ],
      ),
    );
  }
}
