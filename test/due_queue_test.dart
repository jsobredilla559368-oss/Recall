import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/utils/spaced_repetition.dart';
import 'package:recall/features/study/models/card_model.dart';
import 'package:recall/features/decks/screens/deck_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final refNow = DateTime(2026, 9, 17, 12, 0, 0);

  group('SpacedRepetition.isCardDue', () {
    test('brand new unstudied card (repetitions == 0) is always due', () {
      final newCard = FlashcardModel(
        id: 'c1',
        deckId: 'd1',
        front: 'Capital of France?',
        back: 'Paris',
        repetitions: 0,
        nextReviewDate: refNow.add(const Duration(days: 10)), // future date, but unstudied
      );

      expect(SpacedRepetition.isCardDue(newCard, refNow), isTrue);
    });

    test('reviewed card with nextReviewDate in the past is due', () {
      final pastDueCard = FlashcardModel(
        id: 'c2',
        deckId: 'd1',
        front: '2 + 2?',
        back: '4',
        repetitions: 2,
        interval: 6,
        nextReviewDate: refNow.subtract(const Duration(hours: 3)),
      );

      expect(SpacedRepetition.isCardDue(pastDueCard, refNow), isTrue);
    });

    test('reviewed card with nextReviewDate equal to now is due', () {
      final exactDueCard = FlashcardModel(
        id: 'c3',
        deckId: 'd1',
        front: 'H2O?',
        back: 'Water',
        repetitions: 1,
        interval: 1,
        nextReviewDate: refNow,
      );

      expect(SpacedRepetition.isCardDue(exactDueCard, refNow), isTrue);
    });

    test('reviewed card with nextReviewDate in future is NOT due', () {
      final futureCard = MCQModel(
        id: 'c4',
        deckId: 'd1',
        question: 'Speed of light?',
        options: const ['3x10^8 m/s', '100 m/s', '500 km/h', 'Instant'],
        correctIndex: 0,
        repetitions: 3,
        interval: 15,
        nextReviewDate: refNow.add(const Duration(days: 4)),
      );

      expect(SpacedRepetition.isCardDue(futureCard, refNow), isFalse);
    });
  });

  group('SpacedRepetition.filterDueCards', () {
    test('filters out future-scheduled reviewed cards and keeps due cards', () {
      final cards = <CardModel>[
        FlashcardModel(
          id: 'due_new',
          deckId: 'd1',
          front: 'New',
          back: 'New',
          repetitions: 0,
          nextReviewDate: refNow,
        ),
        FlashcardModel(
          id: 'due_past',
          deckId: 'd1',
          front: 'Past',
          back: 'Past',
          repetitions: 2,
          interval: 6,
          nextReviewDate: refNow.subtract(const Duration(days: 1)),
        ),
        FlashcardModel(
          id: 'not_due_future',
          deckId: 'd1',
          front: 'Future',
          back: 'Future',
          repetitions: 2,
          interval: 6,
          nextReviewDate: refNow.add(const Duration(days: 3)),
        ),
      ];

      final due = SpacedRepetition.filterDueCards(cards, refNow);
      expect(due.length, 2);
      expect(due.map((c) => c.id), containsAll(['due_new', 'due_past']));
      expect(due.map((c) => c.id), isNot(contains('not_due_future')));
    });

    test('returns empty list when all cards are scheduled in the future', () {
      final futureCards = <CardModel>[
        FlashcardModel(
          id: 'f1',
          deckId: 'd1',
          front: 'F1',
          back: 'B1',
          repetitions: 1,
          interval: 1,
          nextReviewDate: refNow.add(const Duration(days: 1)),
        ),
        FlashcardModel(
          id: 'f2',
          deckId: 'd1',
          front: 'F2',
          back: 'B2',
          repetitions: 3,
          interval: 10,
          nextReviewDate: refNow.add(const Duration(days: 5)),
        ),
      ];

      final due = SpacedRepetition.filterDueCards(futureCards, refNow);
      expect(due, isEmpty);
    });

    test('returns all cards when all are unstudied or past due', () {
      final allDueCards = <CardModel>[
        FlashcardModel(
          id: 'd1',
          deckId: 'deck',
          front: 'Q1',
          back: 'A1',
          repetitions: 0,
          nextReviewDate: refNow,
        ),
        MCQModel(
          id: 'd2',
          deckId: 'deck',
          question: 'Q2',
          options: const ['A', 'B'],
          correctIndex: 0,
          repetitions: 1,
          nextReviewDate: refNow.subtract(const Duration(hours: 1)),
        ),
      ];

      final due = SpacedRepetition.filterDueCards(allDueCards, refNow);
      expect(due.length, 2);
    });
  });

  group('SpacedRepetition.getBreakdown', () {
    test('correctly partitions cards into mutually exclusive due, learning, and mastered buckets', () {
      final mixedCards = <CardModel>[
        // Mastered & Due (repetitions >= 2, date in past) -> Due bucket
        FlashcardModel(
          id: 'm_due',
          deckId: 'd',
          front: 'M1',
          back: 'A1',
          repetitions: 3,
          interval: 12,
          nextReviewDate: refNow.subtract(const Duration(days: 2)),
        ),
        // Mastered & NOT Due (repetitions >= 2, date in future) -> Mastered bucket
        FlashcardModel(
          id: 'm_future',
          deckId: 'd',
          front: 'M2',
          back: 'A2',
          repetitions: 2,
          interval: 6,
          nextReviewDate: refNow.add(const Duration(days: 4)),
        ),
        // Learning & NOT Due (repetitions == 1, date in future) -> Learning bucket
        FlashcardModel(
          id: 'l_future',
          deckId: 'd',
          front: 'L1',
          back: 'A3',
          repetitions: 1,
          interval: 1,
          nextReviewDate: refNow.add(const Duration(days: 1)),
        ),
        // Unstudied New Card (repetitions == 0) -> Due bucket
        FlashcardModel(
          id: 'new_card',
          deckId: 'd',
          front: 'N1',
          back: 'A4',
          repetitions: 0,
          interval: 0,
          nextReviewDate: refNow,
        ),
      ];

      final breakdown = SpacedRepetition.getBreakdown(mixedCards, refNow);

      // Due cards: m_due (scheduled in past) + new_card (unstudied) = 2
      expect(breakdown['due'], 2);
      // Learning cards: l_future (repetitions == 1, future scheduled) = 1
      expect(breakdown['learning'], 1);
      // Mastered cards: m_future (repetitions >= 2, future scheduled) = 1
      expect(breakdown['mastered'], 1);
      // Total partitions sum to total cards
      expect(breakdown['due']! + breakdown['learning']! + breakdown['mastered']!, mixedCards.length);
    });

    test('returns zero counts for empty deck', () {
      final breakdown = SpacedRepetition.getBreakdown([], refNow);
      expect(breakdown['due'], 0);
      expect(breakdown['learning'], 0);
      expect(breakdown['mastered'], 0);
    });
  });

  group('DeckDetailScreen.calculateMasteryPercentage', () {
    test('computes accurate weighted mastery percentage', () {
      final cards = <CardModel>[
        FlashcardModel(
          id: '1',
          deckId: 'd',
          front: '1',
          back: '1',
          repetitions: 2, // 1.0 (Mastered)
          nextReviewDate: refNow,
        ),
        FlashcardModel(
          id: '2',
          deckId: 'd',
          front: '2',
          back: '2',
          repetitions: 1, // 0.5 (Learning)
          nextReviewDate: refNow,
        ),
        FlashcardModel(
          id: '3',
          deckId: 'd',
          front: '3',
          back: '3',
          repetitions: 0, // 0.0 (New)
          nextReviewDate: refNow,
        ),
        FlashcardModel(
          id: '4',
          deckId: 'd',
          front: '4',
          back: '4',
          repetitions: 0, // 0.0 (New)
          nextReviewDate: refNow,
        ),
      ];

      // Total score: 1.0 + 0.5 + 0.0 + 0.0 = 1.5 out of 4 = 37.5% -> rounded to 38%
      final mastery = DeckDetailScreen.calculateMasteryPercentage(cards);
      expect(mastery, 38);
    });

    test('returns 100% when all cards are mastered', () {
      final cards = <CardModel>[
        FlashcardModel(id: '1', deckId: 'd', front: '1', back: '1', repetitions: 3, nextReviewDate: refNow),
        FlashcardModel(id: '2', deckId: 'd', front: '2', back: '2', repetitions: 2, nextReviewDate: refNow),
      ];
      expect(DeckDetailScreen.calculateMasteryPercentage(cards), 100);
    });

    test('returns 0% when cards list is empty', () {
      expect(DeckDetailScreen.calculateMasteryPercentage([]), 0);
    });
  });
}
