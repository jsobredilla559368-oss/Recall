import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/widgets/recall_button.dart';
import 'package:recall/features/decks/screens/deck_detail_screen.dart';
import 'package:recall/features/study/models/card_model.dart';

void main() {
  group('DeckDetailScreen Mastery Calculation Tests', () {
    test('calculateMasteryPercentage returns 0 for an empty card list', () {
      final mastery = DeckDetailScreen.calculateMasteryPercentage([]);
      expect(mastery, equals(0));
    });

    test('calculateMasteryPercentage returns 100 when all cards are mastered', () {
      final cards = [
        FlashcardModel(
          id: '1',
          deckId: 'd1',
          nextReviewDate: DateTime.now(),
          front: 'Question 1',
          back: 'Answer 1',
          repetitions: 3,
          interval: 10,
        ),
        FlashcardModel(
          id: '2',
          deckId: 'd1',
          nextReviewDate: DateTime.now(),
          front: 'Question 2',
          back: 'Answer 2',
          repetitions: 2,
          interval: 6,
        ),
      ];

      final mastery = DeckDetailScreen.calculateMasteryPercentage(cards);
      expect(mastery, equals(100));
    });

    test('calculateMasteryPercentage calculates weighted mastery for mixed card progress', () {
      final cards = [
        FlashcardModel(
          id: '1',
          deckId: 'd1',
          nextReviewDate: DateTime.now(),
          front: 'Q1',
          back: 'A1',
          repetitions: 3, // Mastered (1.0)
          interval: 8,
        ),
        FlashcardModel(
          id: '2',
          deckId: 'd1',
          nextReviewDate: DateTime.now(),
          front: 'Q2',
          back: 'A2',
          repetitions: 1, // Learning (0.5)
          interval: 1,
        ),
        FlashcardModel(
          id: '3',
          deckId: 'd1',
          nextReviewDate: DateTime.now(),
          front: 'Q3',
          back: 'A3',
          repetitions: 0, // New (0.0)
          interval: 0,
        ),
        FlashcardModel(
          id: '4',
          deckId: 'd1',
          nextReviewDate: DateTime.now(),
          front: 'Q4',
          back: 'A4',
          repetitions: 0, // New (0.0)
          interval: 0,
        ),
      ];

      // Total score = 1.0 + 0.5 + 0 + 0 = 1.5
      // 1.5 / 4 = 0.375 -> 38%
      final mastery = DeckDetailScreen.calculateMasteryPercentage(cards);
      expect(mastery, equals(38));
    });

    test('calculateMasteryPercentage clamps results strictly between 0 and 100', () {
      final cards = List.generate(
        10,
        (i) => FlashcardModel(
          id: 'c$i',
          deckId: 'd1',
          nextReviewDate: DateTime.now(),
          front: 'Q$i',
          back: 'A$i',
          repetitions: 10,
          interval: 50,
        ),
      );

      final mastery = DeckDetailScreen.calculateMasteryPercentage(cards);
      expect(mastery, inInclusiveRange(0, 100));
      expect(mastery, equals(100));
    });
  });

  group('RecallButton Disabled & Interactive State Tests', () {
    testWidgets('RecallButton renders properly and is disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecallButton(
              label: 'Disabled Action',
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.text('Disabled Action'), findsOneWidget);
      final elevatedButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(elevatedButton.enabled, isFalse);
    });

    testWidgets('RecallButton fires callback when enabled', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecallButton(
              label: 'Active Action',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Active Action'));
      expect(tapped, isTrue);
    });
  });
}
