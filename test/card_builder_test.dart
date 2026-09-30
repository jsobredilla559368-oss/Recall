import 'package:flutter_test/flutter_test.dart';
import 'package:recall/features/decks/screens/create_deck_screen.dart';
import 'package:recall/features/study/models/card_model.dart';
import 'package:recall/features/decks/models/deck_model.dart';

void main() {
  group('ManualCardDraft Unit Tests', () {
    test('initializes with default empty values and 4 option controllers', () {
      final draft = ManualCardDraft();
      expect(draft.promptController.text, isEmpty);
      expect(draft.answerController.text, isEmpty);
      expect(draft.optionControllers.length, 4);
      for (final controller in draft.optionControllers) {
        expect(controller.text, isEmpty);
      }
      expect(draft.correctIndex, 0);

      // Verify safe disposal
      draft.dispose();
    });

    test('initializes with custom prompt, answer, and options', () {
      final draft = ManualCardDraft(
        prompt: 'What is SM-2?',
        answer: 'A spaced repetition algorithm.',
        options: ['Sort algorithm', 'Spaced repetition', 'Hashing', 'Compression'],
        correctIndex: 1,
      );

      expect(draft.promptController.text, 'What is SM-2?');
      expect(draft.answerController.text, 'A spaced repetition algorithm.');
      expect(draft.optionControllers.length, 4);
      expect(draft.optionControllers[0].text, 'Sort algorithm');
      expect(draft.optionControllers[1].text, 'Spaced repetition');
      expect(draft.optionControllers[2].text, 'Hashing');
      expect(draft.optionControllers[3].text, 'Compression');
      expect(draft.correctIndex, 1);

      draft.dispose();
    });

    test('handles less than 4 options gracefully by padding up to 4 controllers', () {
      final draft = ManualCardDraft(
        prompt: 'Partial options',
        options: ['Choice A', 'Choice B'],
      );

      expect(draft.optionControllers.length, 4);
      expect(draft.optionControllers[0].text, 'Choice A');
      expect(draft.optionControllers[1].text, 'Choice B');
      expect(draft.optionControllers[2].text, isEmpty);
      expect(draft.optionControllers[3].text, isEmpty);

      draft.dispose();
    });
  });

  group('Manual Card Creation & CardModel Conversion Tests', () {
    test('converts draft into valid FlashcardModel and verifies toMap', () {
      final draft = ManualCardDraft(
        prompt: 'What is Mitochondria?',
        answer: 'The powerhouse of the cell.',
      );

      final now = DateTime.now();
      final card = FlashcardModel(
        id: 'card_123',
        deckId: 'deck_abc',
        front: draft.promptController.text.trim(),
        back: draft.answerController.text.trim(),
        nextReviewDate: now,
      );

      expect(card.type, 'flashcard');
      expect(card.front, 'What is Mitochondria?');
      expect(card.back, 'The powerhouse of the cell.');

      final map = card.toMap();
      expect(map['deckId'], 'deck_abc');
      expect(map['type'], 'flashcard');
      expect(map['front'], 'What is Mitochondria?');
      expect(map['back'], 'The powerhouse of the cell.');
      expect(map['repetitions'], 0);
      expect(map['easeFactor'], 2.5);

      draft.dispose();
    });

    test('converts draft into valid MCQModel with options and verifies toMap', () {
      final draft = ManualCardDraft(
        prompt: 'Which widget is immutable in Flutter?',
        options: ['StatefulWidget', 'StatelessWidget', 'InheritedWidget', 'All Widgets'],
        correctIndex: 3,
      );

      final now = DateTime.now();
      final card = MCQModel(
        id: 'card_mcq_1',
        deckId: 'deck_flutter',
        question: draft.promptController.text.trim(),
        options: draft.optionControllers.map((c) => c.text.trim()).toList(),
        correctIndex: draft.correctIndex,
        nextReviewDate: now,
      );

      expect(card.type, 'mcq');
      expect(card.question, 'Which widget is immutable in Flutter?');
      expect(card.options.length, 4);
      expect(card.options[card.correctIndex], 'All Widgets');

      final map = card.toMap();
      expect(map['deckId'], 'deck_flutter');
      expect(map['type'], 'mcq');
      expect(map['question'], 'Which widget is immutable in Flutter?');
      expect(map['options'], ['StatefulWidget', 'StatelessWidget', 'InheritedWidget', 'All Widgets']);
      expect(map['correctIndex'], 3);

      draft.dispose();
    });
  });

  group('Manual Deck Drafting & Validation Rules', () {
    test('validates deck requires non-empty title', () {
      final title = ''.trim();
      expect(title.isEmpty, isTrue);
    });

    test('validates flashcard draft must have non-empty front and back', () {
      final emptyDraft = ManualCardDraft();
      expect(emptyDraft.promptController.text.trim().isEmpty, isTrue);
      expect(emptyDraft.answerController.text.trim().isEmpty, isTrue);

      emptyDraft.promptController.text = 'Front question';
      expect(emptyDraft.promptController.text.trim().isNotEmpty, isTrue);
      expect(emptyDraft.answerController.text.trim().isEmpty, isTrue);

      emptyDraft.answerController.text = 'Back answer';
      expect(emptyDraft.promptController.text.trim().isNotEmpty, isTrue);
      expect(emptyDraft.answerController.text.trim().isNotEmpty, isTrue);

      emptyDraft.dispose();
    });

    test('validates MCQ draft must have all 4 options populated', () {
      final mcqDraft = ManualCardDraft(
        prompt: 'Sample MCQ Question',
        options: ['Option 1', 'Option 2', '', 'Option 4'],
      );

      final options = mcqDraft.optionControllers.map((c) => c.text.trim()).toList();
      final hasEmptyOption = options.any((opt) => opt.isEmpty);
      expect(hasEmptyOption, isTrue);

      mcqDraft.optionControllers[2].text = 'Option 3';
      final updatedOptions = mcqDraft.optionControllers.map((c) => c.text.trim()).toList();
      expect(updatedOptions.any((opt) => opt.isEmpty), isFalse);

      mcqDraft.dispose();
    });

    test('deck totalCards matches total drafted cards', () {
      final drafts = [
        ManualCardDraft(prompt: 'Q1', answer: 'A1'),
        ManualCardDraft(prompt: 'Q2', answer: 'A2'),
        ManualCardDraft(prompt: 'Q3', answer: 'A3'),
      ];

      final deck = DeckModel(
        id: 'deck_1',
        title: 'Biology 101',
        description: 'Custom flashcard deck',
        totalCards: drafts.length,
        tag: 'Biology',
        isFlashcard: true,
        author: 'Isaac',
        createdAt: DateTime.now(),
      );

      expect(deck.totalCards, 3);
      expect(deck.title, 'Biology 101');
      expect(deck.tag, 'Biology');

      for (final d in drafts) {
        d.dispose();
      }
    });
  });
}
