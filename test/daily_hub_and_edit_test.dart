import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/utils/spaced_repetition.dart';
import 'package:recall/core/widgets/deck_card.dart';
import 'package:recall/features/decks/models/deck_model.dart';
import 'package:recall/features/study/models/card_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final refNow = DateTime(2026, 9, 17, 12, 0, 0);

  group('DeckCard with dueCount property', () {
    testWidgets('renders DUE badge when dueCount is greater than 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeckCard(
              title: 'Neuroanatomy',
              subtitle: 'Cranial nerves and pathways',
              totalCards: 25,
              tag: 'Medicine',
              dueCount: 7,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('7 DUE'), findsOneWidget);
      expect(find.text('25 Cards'), findsOneWidget);
      expect(find.text('Neuroanatomy'), findsOneWidget);
    });

    testWidgets('does NOT render DUE badge when dueCount is 0 or null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DeckCard(
                  title: 'Deck Zero',
                  subtitle: 'No cards due',
                  totalCards: 10,
                  tag: 'Science',
                  dueCount: 0,
                  onTap: () {},
                ),
                DeckCard(
                  title: 'Deck Null',
                  subtitle: 'Null due count',
                  totalCards: 15,
                  tag: 'History',
                  dueCount: null,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining('DUE'), findsNothing);
      expect(find.text('10 Cards'), findsOneWidget);
      expect(find.text('15 Cards'), findsOneWidget);
    });
  });

  group('DeckModel copyWith for Metadata Editing', () {
    test('updates title, description, tag, and isPublic while preserving id, author, createdBy, and createdAt', () {
      final original = DeckModel(
        id: 'deck_orig',
        title: 'Original Title',
        description: 'Original Description',
        totalCards: 30,
        tag: 'OriginalTag',
        author: 'Isaac Dev',
        createdBy: 'uid_123',
        createdAt: DateTime(2026, 1, 1),
        isPublic: false,
      );

      final updated = original.copyWith(
        title: 'Updated Biochemistry Title',
        description: 'Enzyme kinetics and metabolic pathways.',
        tag: 'Biochemistry',
        isPublic: true,
      );

      expect(updated.id, 'deck_orig');
      expect(updated.title, 'Updated Biochemistry Title');
      expect(updated.description, 'Enzyme kinetics and metabolic pathways.');
      expect(updated.tag, 'Biochemistry');
      expect(updated.isPublic, isTrue);
      expect(updated.author, 'Isaac Dev');
      expect(updated.createdBy, 'uid_123');
      expect(updated.createdAt, DateTime(2026, 1, 1));
      expect(updated.totalCards, 30);
    });
  });

  group('Daily Due Review Aggregator Logic', () {
    test('accurately aggregates due counts and decks needing review across multiple decks', () {
      final deck1Cards = <CardModel>[
        FlashcardModel(
          id: 'c1',
          deckId: 'd1',
          front: 'Q1',
          back: 'A1',
          repetitions: 0, // Due (new)
          nextReviewDate: refNow,
        ),
        FlashcardModel(
          id: 'c2',
          deckId: 'd1',
          front: 'Q2',
          back: 'A2',
          repetitions: 2,
          interval: 6,
          nextReviewDate: refNow.add(const Duration(days: 4)), // Not due
        ),
      ];

      final deck2Cards = <CardModel>[
        FlashcardModel(
          id: 'c3',
          deckId: 'd2',
          front: 'Q3',
          back: 'A3',
          repetitions: 1,
          interval: 1,
          nextReviewDate: refNow.subtract(const Duration(hours: 1)), // Due (past)
        ),
        FlashcardModel(
          id: 'c4',
          deckId: 'd2',
          front: 'Q4',
          back: 'A4',
          repetitions: 0, // Due (new)
          nextReviewDate: refNow,
        ),
      ];

      final deck3Cards = <CardModel>[
        FlashcardModel(
          id: 'c5',
          deckId: 'd3',
          front: 'Q5',
          back: 'A5',
          repetitions: 3,
          interval: 15,
          nextReviewDate: refNow.add(const Duration(days: 7)), // Not due
        ),
      ];

      final allDecksCards = {
        'd1': deck1Cards,
        'd2': deck2Cards,
        'd3': deck3Cards,
      };

      int totalDue = 0;
      int decksWithDue = 0;
      String? firstDueDeckId;
      final Map<String, int> dueMap = {};

      allDecksCards.forEach((deckId, cards) {
        final due = SpacedRepetition.filterDueCards(cards, refNow);
        final count = due.length;
        dueMap[deckId] = count;
        if (count > 0) {
          totalDue += count;
          decksWithDue++;
          firstDueDeckId ??= deckId;
        }
      });

      expect(totalDue, 3); // c1 from d1, c3 and c4 from d2
      expect(decksWithDue, 2); // d1 and d2
      expect(firstDueDeckId, 'd1');
      expect(dueMap['d1'], 1);
      expect(dueMap['d2'], 2);
      expect(dueMap['d3'], 0);
    });
  });
}
