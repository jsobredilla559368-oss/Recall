import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';

enum AchievementTier { bronze, silver, gold, diamond }

class AchievementModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final AchievementTier tier;
  final int targetCount;
  final int currentCount;
  final String unit;
  final int xpReward;
  final bool isUnlocked;

  const AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.tier,
    required this.targetCount,
    required this.currentCount,
    required this.unit,
    required this.xpReward,
    required this.isUnlocked,
  });

  double get progress =>
      targetCount == 0 ? 0.0 : (currentCount / targetCount).clamp(0.0, 1.0);

  String get tierName {
    switch (tier) {
      case AchievementTier.bronze:
        return 'Bronze Milestone';
      case AchievementTier.silver:
        return 'Silver Milestone';
      case AchievementTier.gold:
        return 'Gold Milestone';
      case AchievementTier.diamond:
        return 'Diamond Milestone';
    }
  }

  /// Factory helper that computes status from real user profile data
  static List<AchievementModel> evaluateAll({
    required int streakDays,
    required int cardsStudied,
    required int userRank,
    required double accuracy,
    required List<String> unlockedIds,
  }) {
    return [
      AchievementModel(
        id: 'streak_7',
        title: '7-Day Scholar',
        description: 'Maintain an active daily study streak for 7 consecutive days.',
        icon: LucideIcons.flame,
        primaryColor: AppColors.amber,
        tier: AchievementTier.gold,
        targetCount: 7,
        currentCount: streakDays,
        unit: 'Days',
        xpReward: 250,
        isUnlocked: streakDays >= 7 || unlockedIds.contains('streak_7'),
      ),
      AchievementModel(
        id: 'top_3',
        title: 'Top 3 Podium',
        description: 'Climb into the top 3 global scholars on the competitive leaderboard.',
        icon: LucideIcons.crown,
        primaryColor: const Color(0xFFFFB703),
        tier: AchievementTier.diamond,
        targetCount: 3,
        currentCount: (userRank > 0 && userRank <= 3) ? userRank : (userRank > 0 ? userRank : 0),
        unit: 'Rank',
        xpReward: 500,
        isUnlocked: (userRank > 0 && userRank <= 3) || unlockedIds.contains('top_3'),
      ),
      AchievementModel(
        id: 'cards_100',
        title: 'Century Club',
        description: 'Study and practice 100 flashcards or diagnostic quiz questions.',
        icon: LucideIcons.sparkles,
        primaryColor: AppColors.accent,
        tier: AchievementTier.silver,
        targetCount: 100,
        currentCount: cardsStudied,
        unit: 'Cards',
        xpReward: 200,
        isUnlocked: cardsStudied >= 100 || unlockedIds.contains('cards_100'),
      ),
      AchievementModel(
        id: 'quiz_ace',
        title: 'Quiz Ace',
        description: 'Complete a study session with a flawless 100% retrieval accuracy score.',
        icon: LucideIcons.award,
        primaryColor: AppColors.success,
        tier: AchievementTier.gold,
        targetCount: 100,
        currentCount: (accuracy * 100).round(),
        unit: '% Accuracy',
        xpReward: 300,
        isUnlocked: accuracy >= 1.0 || unlockedIds.contains('quiz_ace'),
      ),
      AchievementModel(
        id: 'cards_500',
        title: 'Domain Master',
        description: 'Accumulate deep subject mastery by reviewing over 500 cards.',
        icon: LucideIcons.trophy,
        primaryColor: const Color(0xFF8B5CF6),
        tier: AchievementTier.diamond,
        targetCount: 500,
        currentCount: cardsStudied,
        unit: 'Cards',
        xpReward: 1000,
        isUnlocked: cardsStudied >= 500 || unlockedIds.contains('cards_500'),
      ),
    ];
  }
}
