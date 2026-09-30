import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/decks/models/deck_model.dart';
import '../../features/study/models/card_model.dart';

abstract class IDeckService {
  Future<List<DeckModel>> getRecentDecks();
  Future<List<DeckModel>> getYourDecks();
  Future<DeckModel?> getDeckById(String id);
  Future<List<DeckModel>> getExploreDecks();
  Future<DeckModel> createDeck(DeckModel deck, List<CardModel> cards);
  Future<void> deleteDeck(String deckId);
  Future<DeckModel?> importDeck(String deckId);
  Future<void> addCardToDeck(String deckId, CardModel card);
  Future<void> updateCard(String deckId, CardModel card);
  Future<void> deleteCard(String deckId, String cardId);
  Future<void> updateDeckMetadata({
    required String deckId,
    required String title,
    required String description,
    required String tag,
    required bool isPublic,
  });
}

class DeckService extends ChangeNotifier implements IDeckService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSubscription;
  
  // Cache to prevent excessive reads during UI rebuilds
  List<DeckModel> _recentDecks = [];
  List<DeckModel> _yourDecks = [];
  List<DeckModel> _exploreDecks = [];

  List<DeckModel> get recentDecks => _recentDecks;
  List<DeckModel> get yourDecks => _yourDecks;
  List<DeckModel> get exploreDecks => _exploreDecks;

  bool _isLoading = false;
  bool _isFetching = false;
  bool _hasFetched = false;

  bool get isLoading => _isLoading;

  DeckService() {
    _fetchDecks();
    _authSubscription = _auth.authStateChanges().listen((User? user) {
      // Re-fetch personal decks when user logs in or out
      refreshDecks();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> refreshDecks() => _fetchDecks(force: true);

  Future<void> _fetchDecks({bool force = false}) async {
    if (_isFetching) return;
    if (_hasFetched && !force) return;

    _isFetching = true;
    _isLoading = true;

    try {
      final currentUid = _auth.currentUser?.uid ?? '';

      // Query 1: Public Explore Decks
      final exploreSnap = await _firestore.collection('decks')
          .where('isPublic', isEqualTo: true)
          .get();
      _exploreDecks = exploreSnap.docs.map((doc) => DeckModel.fromMap(doc.id, doc.data())).toList();
      _exploreDecks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Query 2: Personal Decks
      if (currentUid.isNotEmpty) {
        final personalSnap = await _firestore.collection('decks')
            .where('createdBy', isEqualTo: currentUid)
            .get();
        _yourDecks = personalSnap.docs.map((doc) => DeckModel.fromMap(doc.id, doc.data())).toList();
        _yourDecks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        // Guest mode: fetch templates
        final guestSnap = await _firestore.collection('decks')
            .where('createdBy', isEqualTo: '')
            .get();
        _yourDecks = guestSnap.docs.map((doc) => DeckModel.fromMap(doc.id, doc.data())).toList();
        _yourDecks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      if (_exploreDecks.isEmpty && _yourDecks.isEmpty) {
        await _seedMockData();
        return; 
      }

      // Calculate Recent Decks
      final combined = [..._yourDecks, ..._exploreDecks];
      final uniqueDecks = {for (var d in combined) d.id: d}.values.toList();
      uniqueDecks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _recentDecks = uniqueDecks.take(3).toList();

      _hasFetched = true;
    } catch (e) {
      debugPrint("Error fetching decks: $e");
    } finally {
      _isFetching = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<List<DeckModel>> getRecentDecks() async {
    if (!_hasFetched && !_isFetching) await _fetchDecks();
    return _recentDecks;
  }

  @override
  Future<List<DeckModel>> getYourDecks() async {
    if (!_hasFetched && !_isFetching) await _fetchDecks();
    return _yourDecks;
  }

  @override
  Future<List<DeckModel>> getExploreDecks() async {
    if (!_hasFetched && !_isFetching) await _fetchDecks();
    return _exploreDecks;
  }

  @override
  Future<DeckModel?> getDeckById(String id) async {
    try {
      final doc = await _firestore.collection('decks').doc(id).get();
      if (doc.exists && doc.data() != null) {
        return DeckModel.fromMap(doc.id, doc.data()!);
      }
    } catch (e) {
      debugPrint("Error fetching deck by ID: $e");
    }
    return null;
  }

  @override
  Future<DeckModel> createDeck(DeckModel deck, List<CardModel> cards) async {
    _isLoading = true;
    notifyListeners();

    try {
      final currentUid = _auth.currentUser?.uid ?? '';
      final currentEmail = _auth.currentUser?.displayName ?? _auth.currentUser?.email ?? 'Learner';

      final deckRef = _firestore.collection('decks').doc();
      final finalDeck = deck.copyWith(
        id: deckRef.id,
        createdBy: currentUid,
        author: deck.author.isEmpty ? currentEmail : deck.author,
        totalCards: cards.length,
        createdAt: DateTime.now(),
      );

      final batch = _firestore.batch();
      batch.set(deckRef, finalDeck.toMap());

      for (final card in cards) {
        final cardRef = deckRef.collection('cards').doc();
        final cardData = card.toMap();
        cardData['deckId'] = deckRef.id;
        batch.set(cardRef, cardData);
      }

      await batch.commit();
      debugPrint("Successfully persisted deck ${deckRef.id} with ${cards.length} cards to Firestore.");
      
      await _fetchDecks(force: true);
      return finalDeck;
    } catch (e) {
      debugPrint("Error creating deck: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<void> deleteDeck(String deckId) async {
    try {
      _recentDecks.removeWhere((d) => d.id == deckId);
      _yourDecks.removeWhere((d) => d.id == deckId);
      _exploreDecks.removeWhere((d) => d.id == deckId);
      notifyListeners();

      final cardsSnap = await _firestore.collection('decks').doc(deckId).collection('cards').get();
      final batch = _firestore.batch();
      for (final card in cardsSnap.docs) {
        batch.delete(card.reference);
      }
      batch.delete(_firestore.collection('decks').doc(deckId));
      await batch.commit();

      await _fetchDecks(force: true);
    } catch (e) {
      debugPrint("Error deleting deck: $e");
      rethrow;
    }
  }

  @override
  Future<DeckModel?> importDeck(String deckId) async {
    try {
      final original = await getDeckById(deckId);
      if (original == null) return null;

      final cardsSnap = await _firestore.collection('decks').doc(deckId).collection('cards').get();
      final cards = cardsSnap.docs.map((doc) => CardModel.fromMap(doc.id, doc.data())).toList();

      final currentUid = _auth.currentUser?.uid ?? '';
      final currentName = _auth.currentUser?.displayName ?? 'Learner';

      final importedDeck = original.copyWith(
        id: '',
        title: '${original.title} (Imported)',
        createdBy: currentUid,
        author: currentName,
        isPublic: false,
        createdAt: DateTime.now(),
      );

      final created = await createDeck(importedDeck, cards);
      debugPrint("Successfully imported deck $deckId as ${created.id}");
      return created;
    } catch (e) {
      debugPrint("Error importing deck: $e");
      return null;
    }
  }

  @override
  Future<void> addCardToDeck(String deckId, CardModel card) async {
    try {
      final cardRef = _firestore.collection('decks').doc(deckId).collection('cards').doc();
      final cardData = card.toMap();
      cardData['deckId'] = deckId;
      await cardRef.set(cardData);

      await _firestore.collection('decks').doc(deckId).update({
        'totalCards': FieldValue.increment(1),
      });

      await _fetchDecks(force: true);
      notifyListeners();
    } catch (e) {
      debugPrint("Error adding card to deck: $e");
      rethrow;
    }
  }

  @override
  Future<void> updateCard(String deckId, CardModel card) async {
    try {
      final cardData = card.toMap();
      cardData['deckId'] = deckId;
      await _firestore
          .collection('decks')
          .doc(deckId)
          .collection('cards')
          .doc(card.id)
          .update(cardData);

      await _fetchDecks(force: true);
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating card: $e");
      rethrow;
    }
  }

  @override
  Future<void> deleteCard(String deckId, String cardId) async {
    try {
      await _firestore
          .collection('decks')
          .doc(deckId)
          .collection('cards')
          .doc(cardId)
          .delete();

      await _firestore.collection('decks').doc(deckId).update({
        'totalCards': FieldValue.increment(-1),
      });

      await _fetchDecks(force: true);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting card: $e");
      rethrow;
    }
  }

  @override
  Future<void> updateDeckMetadata({
    required String deckId,
    required String title,
    required String description,
    required String tag,
    required bool isPublic,
  }) async {
    try {
      await _firestore.collection('decks').doc(deckId).update({
        'title': title.trim(),
        'description': description.trim(),
        'tag': tag.trim(),
        'isPublic': isPublic,
      });

      await _fetchDecks(force: true);
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating deck metadata: $e");
      rethrow;
    }
  }

  Future<void> _seedMockData() async {
    final currentUid = _auth.currentUser?.uid ?? '';
    if (currentUid.isEmpty) {
      debugPrint("Skipping deck seed: No authenticated user. Deferring seed.");
      return;
    }
    debugPrint("Seeding Firestore with initial decks & cards...");

    final mockDecksWithCards = [
      {
        'deck': DeckModel(
          id: '',
          title: 'Advanced Flutter Architecture',
          description: 'Mastering Provider, Riverpod, and Bloc patterns in modern Flutter.',
          totalCards: 3,
          tag: 'Flutter',
          isFlashcard: false,
          author: 'Isaac',
          createdBy: currentUid,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          isPublic: false,
        ),
        'cards': [
          MCQModel(
            id: '',
            deckId: '',
            nextReviewDate: DateTime.now(),
            question: 'Which method on ChangeNotifier notifies all listening widgets to rebuild?',
            options: ['notifyListeners()', 'setState()', 'rebuild()', 'update()'],
            correctIndex: 0,
          ),
          MCQModel(
            id: '',
            deckId: '',
            nextReviewDate: DateTime.now(),
            question: 'What is the primary benefit of the Provider pattern over inherited widgets?',
            options: ['Less boilerplate & cleaner dependency injection', 'Faster compiled bytecode', 'Automatic local database caching', 'Cross-platform compilation'],
            correctIndex: 0,
          ),
          MCQModel(
            id: '',
            deckId: '',
            nextReviewDate: DateTime.now(),
            question: 'Which widget listens for changes from a Provider and rebuilds only its descendants?',
            options: ['Consumer', 'InheritedModel', 'StatefulBuilder', 'StreamBuilder'],
            correctIndex: 0,
          ),
        ],
      },
      {
        'deck': DeckModel(
          id: '',
          title: 'System Design Interview Essentials',
          description: 'Core concepts for passing big tech system design interviews.',
          totalCards: 3,
          tag: 'Engineering',
          isFlashcard: true,
          author: 'Isaac',
          createdBy: currentUid,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          isPublic: false,
        ),
        'cards': [
          FlashcardModel(
            id: '',
            deckId: '',
            nextReviewDate: DateTime.now(),
            front: 'What does the CAP Theorem state?',
            back: 'A distributed system can only provide at most two of: Consistency, Availability, and Partition Tolerance.',
          ),
          FlashcardModel(
            id: '',
            deckId: '',
            nextReviewDate: DateTime.now(),
            front: 'What is the purpose of a Load Balancer?',
            back: 'Distributes incoming network traffic evenly across a cluster of backend servers to ensure high availability and responsiveness.',
          ),
          FlashcardModel(
            id: '',
            deckId: '',
            nextReviewDate: DateTime.now(),
            front: 'Difference between Horizontal vs. Vertical Scaling?',
            back: 'Vertical: Adding more CPU/RAM to a single server.\nHorizontal: Adding more servers/machines to the pool.',
          ),
        ],
      },
      {
        'deck': DeckModel(
          id: '',
          title: 'Spanish Vocabulary B2',
          description: 'Essential words and phrases for upper-intermediate Spanish.',
          totalCards: 3,
          tag: 'Language',
          isFlashcard: true,
          author: 'Elena R.',
          createdBy: 'system_curated',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          isPublic: true,
        ),
        'cards': [
          FlashcardModel(
            id: '',
            deckId: '',
            nextReviewDate: DateTime.now(),
            front: 'What does "Sin embargo" mean in English?',
            back: 'However / Nevertheless',
          ),
          FlashcardModel(
            id: '',
            deckId: '',
            nextReviewDate: DateTime.now(),
            front: 'Translate: "Me hace ilusión"',
            back: 'I am excited / looking forward to it',
          ),
          FlashcardModel(
            id: '',
            deckId: '',
            nextReviewDate: DateTime.now(),
            front: 'What does "Por lo tanto" mean?',
            back: 'Therefore / Consequently',
          ),
        ],
      },
    ];

    final batch = _firestore.batch();
    for (final item in mockDecksWithCards) {
      final deck = item['deck'] as DeckModel;
      final cards = item['cards'] as List<CardModel>;
      final deckRef = _firestore.collection('decks').doc();

      final deckData = deck.toMap();
      deckData['createdAt'] = Timestamp.fromDate(deck.createdAt);
      batch.set(deckRef, deckData);

      for (final card in cards) {
        final cardRef = deckRef.collection('cards').doc();
        final cardData = card.toMap();
        cardData['deckId'] = deckRef.id;
        batch.set(cardRef, cardData);
      }
    }

    await batch.commit();
    await _fetchDecks();
  }
}
