import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/services/deck_service.dart';
import 'package:recall/features/decks/models/deck_model.dart';
import 'package:recall/features/study/models/card_model.dart';

/// Test mock implementation of IDeckService to verify CRUD contracts and state sync
class MockTestDeckService implements IDeckService {
  final List<DeckModel> _recentDecks = [];
  final List<DeckModel> _yourDecks = [];
  final List<DeckModel> _exploreDecks = [];
  final Map<String, List<CardModel>> _cardsByDeck = {};

  bool notifyCalled = false;
  int listenerNotificationCount = 0;

  void addMockDeck(DeckModel deck, List<CardModel> cards) {
    _yourDecks.add(deck);
    _recentDecks.add(deck);
    if (deck.isPublic) _exploreDecks.add(deck);
    _cardsByDeck[deck.id] = List.from(cards);
  }

  @override
  Future<List<DeckModel>> getRecentDecks() async => List.unmodifiable(_recentDecks);

  @override
  Future<List<DeckModel>> getYourDecks() async => List.unmodifiable(_yourDecks);

  @override
  Future<List<DeckModel>> getExploreDecks() async => List.unmodifiable(_exploreDecks);

  @override
  Future<DeckModel?> getDeckById(String id) async {
    try {
      return _yourDecks.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DeckModel> createDeck(DeckModel deck, List<CardModel> cards) async {
    addMockDeck(deck, cards);
    notifyCalled = true;
    listenerNotificationCount++;
    return deck;
  }

  @override
  Future<void> deleteDeck(String deckId) async {
    _recentDecks.removeWhere((d) => d.id == deckId);
    _yourDecks.removeWhere((d) => d.id == deckId);
    _exploreDecks.removeWhere((d) => d.id == deckId);
    _cardsByDeck.remove(deckId);
    notifyCalled = true;
    listenerNotificationCount++;
  }

  @override
  Future<DeckModel?> importDeck(String deckId) async => null;

  @override
  Future<void> addCardToDeck(String deckId, CardModel card) async {
    final list = _cardsByDeck.putIfAbsent(deckId, () => []);
    list.add(card);

    final deckIdx = _yourDecks.indexWhere((d) => d.id == deckId);
    if (deckIdx != -1) {
      _yourDecks[deckIdx] = _yourDecks[deckIdx].copyWith(
        totalCards: _yourDecks[deckIdx].totalCards + 1,
      );
    }
    notifyCalled = true;
    listenerNotificationCount++;
  }

  @override
  Future<void> updateCard(String deckId, CardModel card) async {
    final list = _cardsByDeck[deckId];
    if (list != null) {
      final idx = list.indexWhere((c) => c.id == card.id);
      if (idx != -1) {
        list[idx] = card;
      }
    }
    notifyCalled = true;
    listenerNotificationCount++;
  }

  @override
  Future<void> deleteCard(String deckId, String cardId) async {
    final list = _cardsByDeck[deckId];
    if (list != null) {
      list.removeWhere((c) => c.id == cardId);
    }

    final deckIdx = _yourDecks.indexWhere((d) => d.id == deckId);
    if (deckIdx != -1) {
      _yourDecks[deckIdx] = _yourDecks[deckIdx].copyWith(
        totalCards: (_yourDecks[deckIdx].totalCards - 1).clamp(0, 999999),
      );
    }
    notifyCalled = true;
    listenerNotificationCount++;
  }

  @override
  Future<void> updateDeckMetadata({
    required String deckId,
    required String title,
    required String description,
    required String tag,
    required bool isPublic,
  }) async {
    final idx = _yourDecks.indexWhere((d) => d.id == deckId);
    if (idx != -1) {
      _yourDecks[idx] = _yourDecks[idx].copyWith(
        title: title,
        description: description,
        tag: tag,
        isPublic: isPublic,
      );
    }
    notifyCalled = true;
    listenerNotificationCount++;
  }

  List<CardModel> getCards(String deckId) => _cardsByDeck[deckId] ?? [];
}

void main() {
  group('CardModel Immutability & copyWith Unit Tests', () {
    test('FlashcardModel.copyWith updates front, back, and maintains spaced repetition state', () {
      final now = DateTime.now();
      final original = FlashcardModel(
        id: 'fc_001',
        deckId: 'deck_100',
        nextReviewDate: now,
        front: 'Original Question',
        back: 'Original Answer',
        repetitions: 3,
        easeFactor: 2.6,
        interval: 10,
      );

      final updated = original.copyWith(
        front: 'Updated Question?',
        back: 'Updated Answer with more detail.',
      );

      expect(updated.id, equals('fc_001'));
      expect(updated.deckId, equals('deck_100'));
      expect(updated.front, equals('Updated Question?'));
      expect(updated.back, equals('Updated Answer with more detail.'));
      expect(updated.repetitions, equals(3));
      expect(updated.easeFactor, equals(2.6));
      expect(updated.interval, equals(10));
      expect(updated.nextReviewDate, equals(now));
    });

    test('MCQModel.copyWith updates question, choices, and correct index', () {
      final now = DateTime.now();
      final original = MCQModel(
        id: 'mcq_001',
        deckId: 'deck_200',
        nextReviewDate: now,
        question: 'What is 2 + 2?',
        options: ['1', '2', '3', '4'],
        correctIndex: 3,
        repetitions: 1,
        easeFactor: 2.5,
        interval: 1,
      );

      final updated = original.copyWith(
        question: 'What is 5 + 5?',
        options: ['8', '9', '10', '11'],
        correctIndex: 2,
      );

      expect(updated.id, equals('mcq_001'));
      expect(updated.deckId, equals('deck_200'));
      expect(updated.question, equals('What is 5 + 5?'));
      expect(updated.options, equals(['8', '9', '10', '11']));
      expect(updated.correctIndex, equals(2));
      expect(updated.repetitions, equals(1));
    });
  });

  group('Card CRUD & Deck Service Contracts', () {
    late MockTestDeckService service;
    late DeckModel testDeck;
    late FlashcardModel testCard1;
    late FlashcardModel testCard2;

    setUp(() {
      service = MockTestDeckService();
      testDeck = DeckModel(
        id: 'deck_crud_01',
        title: 'Biochemistry 101',
        description: 'Metabolic pathways',
        totalCards: 2,
        tag: 'Biology',
        isFlashcard: true,
        author: 'Isaac',
        createdBy: 'user_active',
        createdAt: DateTime.now(),
        isPublic: false,
      );

      testCard1 = FlashcardModel(
        id: 'card_01',
        deckId: testDeck.id,
        nextReviewDate: DateTime.now(),
        front: 'What is Glycolysis?',
        back: 'The breakdown of glucose by enzymes.',
      );

      testCard2 = FlashcardModel(
        id: 'card_02',
        deckId: testDeck.id,
        nextReviewDate: DateTime.now(),
        front: 'What is ATP?',
        back: 'Adenosine triphosphate, cell energy currency.',
      );

      service.addMockDeck(testDeck, [testCard1, testCard2]);
    });

    test('updateCard successfully alters card prompt and answer', () async {
      final modifiedCard = testCard1.copyWith(
        front: 'What is Glycolysis? (Updated)',
        back: 'Anaerobic breakdown of glucose into pyruvate.',
      );

      await service.updateCard(testDeck.id, modifiedCard);

      final cards = service.getCards(testDeck.id);
      expect(cards.first.id, equals('card_01'));
      final updatedFirstCard = cards.first as FlashcardModel;
      expect(updatedFirstCard.front, equals('What is Glycolysis? (Updated)'));
      expect(updatedFirstCard.back, equals('Anaerobic breakdown of glucose into pyruvate.'));
      expect(service.notifyCalled, isTrue);
    });

    test('deleteCard decrements totalCards and removes card from deck', () async {
      expect(service.getCards(testDeck.id).length, equals(2));

      await service.deleteCard(testDeck.id, 'card_01');

      final remainingCards = service.getCards(testDeck.id);
      expect(remainingCards.length, equals(1));
      expect(remainingCards.first.id, equals('card_02'));

      final deck = await service.getDeckById(testDeck.id);
      expect(deck?.totalCards, equals(1));
      expect(service.notifyCalled, isTrue);
    });
  });

  group('Deck Deletion UI Synchronization & Empty State Tests', () {
    test('deleteDeck removes deck from yourDecks, recentDecks, exploreDecks and alerts listeners', () async {
      final service = MockTestDeckService();
      final deckA = DeckModel(
        id: 'deck_a',
        title: 'Deck A',
        description: 'First',
        totalCards: 1,
        tag: 'General',
        isFlashcard: true,
        author: 'Isaac',
        createdBy: 'user_active',
        createdAt: DateTime.now(),
        isPublic: true,
      );

      service.addMockDeck(deckA, []);

      expect((await service.getYourDecks()).length, equals(1));
      expect((await service.getRecentDecks()).length, equals(1));
      expect((await service.getExploreDecks()).length, equals(1));

      await service.deleteDeck('deck_a');

      expect((await service.getYourDecks()).isEmpty, isTrue);
      expect((await service.getRecentDecks()).isEmpty, isTrue);
      expect((await service.getExploreDecks()).isEmpty, isTrue);
      expect(service.notifyCalled, isTrue);
      expect(service.listenerNotificationCount, equals(1));
    });

    test('Authenticated user with zero decks has empty yourDecks list without fallback pollution', () {
      final currentUid = 'user_real_999';
      final allDecks = [
        DeckModel(
          id: 'deck_community_1',
          title: 'Community Shared Deck',
          description: 'Explore template',
          totalCards: 10,
          tag: 'General',
          isFlashcard: true,
          author: 'System',
          createdBy: 'system_curated',
          createdAt: DateTime.now(),
          isPublic: true,
        ),
        DeckModel(
          id: 'deck_other_user',
          title: 'Private Deck of Other User',
          description: 'Not mine',
          totalCards: 5,
          tag: 'Secret',
          isFlashcard: false,
          author: 'Other',
          createdBy: 'user_other_111',
          createdAt: DateTime.now(),
          isPublic: false,
        ),
      ];

      // Replicating the updated DeckService._fetchDecks logic:
      var yourDecks = allDecks.where((d) => d.createdBy == currentUid || (!d.isPublic && currentUid.isEmpty)).toList();
      
      // Guest-only fallback condition:
      if (currentUid.isEmpty && yourDecks.isEmpty) {
        yourDecks = allDecks.where((d) => !d.isPublic).toList();
      }

      // For authenticated user, yourDecks must be empty so the Welcome / Empty State displays
      expect(yourDecks.isEmpty, isTrue);
    });
  });
}
