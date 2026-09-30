import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/models/achievement_model.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AchievementModel', () {
    test('calculates progress and clamps accurately between 0.0 and 1.0', () {
      const achievement = AchievementModel(
        id: 'test_1',
        title: 'Test',
        description: 'Test description',
        icon: LucideIcons.trophy,
        primaryColor: Colors.blue,
        tier: AchievementTier.bronze,
        targetCount: 50,
        currentCount: 25,
        unit: 'Cards',
        xpReward: 100,
        isUnlocked: false,
      );

      expect(achievement.progress, 0.5);

      const overAchieved = AchievementModel(
        id: 'test_2',
        title: 'Overachieved',
        description: 'Test description',
        icon: LucideIcons.trophy,
        primaryColor: Colors.blue,
        tier: AchievementTier.gold,
        targetCount: 50,
        currentCount: 150,
        unit: 'Cards',
        xpReward: 100,
        isUnlocked: true,
      );

      expect(overAchieved.progress, 1.0);
    });

    test('returns correct tierName formatting', () {
      const bronze = AchievementModel(
        id: 'b',
        title: 'Bronze',
        description: '',
        icon: LucideIcons.award,
        primaryColor: Colors.brown,
        tier: AchievementTier.bronze,
        targetCount: 10,
        currentCount: 0,
        unit: '',
        xpReward: 50,
        isUnlocked: false,
      );
      expect(bronze.tierName, 'Bronze Milestone');

      const gold = AchievementModel(
        id: 'g',
        title: 'Gold',
        description: '',
        icon: LucideIcons.award,
        primaryColor: Colors.amber,
        tier: AchievementTier.gold,
        targetCount: 10,
        currentCount: 0,
        unit: '',
        xpReward: 50,
        isUnlocked: false,
      );
      expect(gold.tierName, 'Gold Milestone');
    });

    test('evaluateAll marks achievements locked for novice stats', () {
      final achievements = AchievementModel.evaluateAll(
        streakDays: 2,
        cardsStudied: 15,
        userRank: 10,
        accuracy: 0.75,
        unlockedIds: [],
      );

      expect(achievements.length, 5);
      for (final a in achievements) {
        expect(a.isUnlocked, isFalse, reason: '${a.id} should be locked');
      }
    });

    test('evaluateAll marks milestones unlocked when criteria are met', () {
      final achievements = AchievementModel.evaluateAll(
        streakDays: 7,
        cardsStudied: 120,
        userRank: 2,
        accuracy: 1.0,
        unlockedIds: [],
      );

      final streak7 = achievements.firstWhere((a) => a.id == 'streak_7');
      final top3 = achievements.firstWhere((a) => a.id == 'top_3');
      final cards100 = achievements.firstWhere((a) => a.id == 'cards_100');
      final quizAce = achievements.firstWhere((a) => a.id == 'quiz_ace');
      final cards500 = achievements.firstWhere((a) => a.id == 'cards_500');

      expect(streak7.isUnlocked, isTrue);
      expect(top3.isUnlocked, isTrue);
      expect(cards100.isUnlocked, isTrue);
      expect(quizAce.isUnlocked, isTrue);
      expect(cards500.isUnlocked, isFalse); // Only 120 cards
    });

    test('evaluateAll honors persisted unlockedIds even if live stats drop', () {
      final achievements = AchievementModel.evaluateAll(
        streakDays: 0,
        cardsStudied: 10,
        userRank: 50,
        accuracy: 0.5,
        unlockedIds: ['streak_7', 'cards_500'],
      );

      final streak7 = achievements.firstWhere((a) => a.id == 'streak_7');
      final cards500 = achievements.firstWhere((a) => a.id == 'cards_500');
      final top3 = achievements.firstWhere((a) => a.id == 'top_3');

      expect(streak7.isUnlocked, isTrue);
      expect(cards500.isUnlocked, isTrue);
      expect(top3.isUnlocked, isFalse);
    });
  });
}
