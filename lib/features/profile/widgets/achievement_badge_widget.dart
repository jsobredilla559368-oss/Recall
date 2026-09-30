import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/models/achievement_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'achievement_detail_sheet.dart';

class AchievementBadgeWidget extends StatefulWidget {
  final AchievementModel achievement;

  const AchievementBadgeWidget({
    super.key,
    required this.achievement,
  });

  @override
  State<AchievementBadgeWidget> createState() => _AchievementBadgeWidgetState();
}

class _AchievementBadgeWidgetState extends State<AchievementBadgeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.achievement.isUnlocked) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AchievementBadgeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.achievement.isUnlocked && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.achievement.isUnlocked && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          AchievementDetailSheet(achievement: widget.achievement),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final isUnlocked = a.isUnlocked;

    return InkWell(
      onTap: _showDetails,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 86,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge Circular Emblem
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale = isUnlocked ? _pulseAnimation.value : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked
                      ? a.primaryColor.withValues(alpha: 0.15)
                      : AppColors.surface,
                  border: Border.all(
                    color: isUnlocked
                        ? a.primaryColor.withValues(alpha: 0.7)
                        : AppColors.textMuted.withValues(alpha: 0.2),
                    width: isUnlocked ? 2 : 1.5,
                  ),
                  boxShadow: isUnlocked
                      ? [
                          BoxShadow(
                            color: a.primaryColor.withValues(alpha: 0.35),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        a.icon,
                        size: 26,
                        color: isUnlocked ? a.primaryColor : AppColors.textMuted,
                      ),
                      if (!isUnlocked)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.background,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.lock,
                              size: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Badge Title
            Text(
              a.title,
              style: AppTypography.caption.copyWith(
                fontWeight: isUnlocked ? FontWeight.bold : FontWeight.w500,
                color: isUnlocked ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),

            // Status or Progress Indicator
            if (isUnlocked)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.check, size: 10, color: a.primaryColor),
                  const SizedBox(width: 2),
                  Text(
                    'Unlocked',
                    style: AppTypography.caption.copyWith(
                      color: a.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else
              Text(
                '${(a.progress * 100).toInt()}%',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
