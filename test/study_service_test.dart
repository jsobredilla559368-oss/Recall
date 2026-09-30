import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/models/user_model.dart';
import 'package:recall/features/study/models/card_model.dart';
import 'package:recall/features/study/models/card_progress_model.dart';
import 'package:recall/features/study/study_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudyService.calculateUpdatedStreak', () {
    final now = DateTime(2026, 9, 17, 14, 30);

    test('returns 1 when user has never studied before (lastStudyDate is null)', () {
      final streak = StudyService.calculateUpdatedStreak(
        lastStudyDate: null,
        currentStreak: 0,
        now: now,
      );
      expect(streak, 1);
    });

    test('maintains streak when user studies again on the same calendar day', () {
      final earlierToday = DateTime(2026, 9, 17, 9, 0);
      final streak = StudyService.calculateUpdatedStreak(
        lastStudyDate: earlierToday,
        currentStreak: 5,
        now: now,
      );
      expect(streak, 5);
    });

    test('ensures at least 1 streak if user studies on same day but had 0', () {
      final earlierToday = DateTime(2026, 9, 17, 8, 15);
      final streak = StudyService.calculateUpdatedStreak(
        lastStudyDate: earlierToday,
        currentStreak: 0,
        now: now,
      );
      expect(streak, 1);
    });

    test('increments streak when user studies on consecutive day (yesterday)', () {
      final yesterday = DateTime(2026, 9, 16, 21, 0);
      final streak = StudyService.calculateUpdatedStreak(
        lastStudyDate: yesterday,
        currentStreak: 7,
        now: now,
      );
      expect(streak, 8);
    });

    test('resets streak to 1 when user misses one or more days (> 1 day gap)', () {
      final twoDaysAgo = DateTime(2026, 9, 15, 10, 0);
      final streak = StudyService.calculateUpdatedStreak(
        lastStudyDate: twoDaysAgo,
        currentStreak: 42,
        now: now,
      );
      expect(streak, 1);

      final fiveDaysAgo = DateTime(2026, 9, 12, 10, 0);
      final resetStreak = StudyService.calculateUpdatedStreak(
        lastStudyDate: fiveDaysAgo,
        currentStreak: 100,
        now: now,
      );
      expect(resetStreak, 1);
    });
  });

  group('CardProgressModel & CardModel overlay', () {
    test('CardProgressModel serializes to and from Map correctly', () {
      final reviewDate = DateTime(2026, 9, 25, 12, 0);
      final reviewedAt = DateTime(2026, 9, 17, 10, 0);

      final progress = CardProgressModel(
        cardId: 'card_abc',
        deckId: 'deck_xyz',
        repetitions: 3,
        easeFactor: 2.6,
        interval: 6,
        nextReviewDate: reviewDate,
        lastReviewedAt: reviewedAt,
      );

      final map = progress.toMap();
      expect(map['deckId'], 'deck_xyz');
      expect(map['repetitions'], 3);
      expect(map['easeFactor'], 2.6);
      expect(map['interval'], 6);
      expect(map['nextReviewDate'], isA<Timestamp>());

      final deserialized = CardProgressModel.fromMap('card_abc', map);
      expect(deserialized.cardId, 'card_abc');
      expect(deserialized.deckId, 'deck_xyz');
      expect(deserialized.repetitions, 3);
      expect(deserialized.easeFactor, 2.6);
      expect(deserialized.interval, 6);
      expect(deserialized.nextReviewDate.year, 2026);
    });

    test('CardModel.applyProgress updates spaced repetition state in-place', () {
      final card = FlashcardModel(
        id: 'card_1',
        deckId: 'deck_1',
        front: 'Front text',
        back: 'Back text',
        nextReviewDate: DateTime(2026, 1, 1),
        repetitions: 0,
        easeFactor: 2.5,
        interval: 0,
      );

      final userProgress = CardProgressModel(
        cardId: 'card_1',
        deckId: 'deck_1',
        repetitions: 4,
        easeFactor: 2.7,
        interval: 15,
        nextReviewDate: DateTime(2026, 10, 2),
      );

      card.applyProgress(userProgress);

      expect(card.repetitions, 4);
      expect(card.easeFactor, 2.7);
      expect(card.interval, 15);
      expect(card.nextReviewDate, DateTime(2026, 10, 2));
    });
  });

  group('UserModel with lastStudyDate', () {
    test('serializes and parses lastStudyDate timestamp correctly', () {
      final studyDate = DateTime(2026, 9, 16, 18, 45);
      final user = UserModel(
        uid: 'user_test',
        displayName: 'Dr. Test',
        score: 500,
        streakCount: 3,
        totalCardsStudied: 30,
        lastStudyDate: studyDate,
      );

      final map = user.toMap();
      expect(map['lastStudyDate'], isA<Timestamp>());

      final parsed = UserModel.fromMap('user_test', map);
      expect(parsed.lastStudyDate, isNotNull);
      expect(parsed.lastStudyDate!.year, 2026);
      expect(parsed.lastStudyDate!.month, 9);
      expect(parsed.lastStudyDate!.day, 16);
    });

    test('copyWith preserves or modifies lastStudyDate cleanly', () {
      final initialDate = DateTime(2026, 9, 10);
      final user = UserModel(
        uid: 'user_test',
        displayName: 'Scholar',
        lastStudyDate: initialDate,
      );

      final updatedDate = DateTime(2026, 9, 17);
      final updated = user.copyWith(lastStudyDate: updatedDate, streakCount: 5);

      expect(updated.lastStudyDate, updatedDate);
      expect(updated.streakCount, 5);
      expect(updated.displayName, 'Scholar');
    });
  });
}
