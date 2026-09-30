import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/achievement_model.dart';
import '../../core/utils/spaced_repetition.dart';
import 'models/card_model.dart';
import 'models/card_progress_model.dart';
import 'models/session_model.dart';

abstract class IStudyService {
  Future<List<CardModel>> getCardsForDeck(String deckId, bool isFlashcard);
  Future<List<CardModel>> getDueCardsForDeck(String deckId, bool isFlashcard, [DateTime? asOf]);
  Future<void> recordAnswer(CardModel card, bool passed);
  Future<List<AchievementModel>> recordSession(SessionModel session);
}

class StudyService extends ChangeNotifier implements IStudyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Mathematically evaluates consecutive study days comparing previous
  /// lastStudyDate against the current timestamp.
  static int calculateUpdatedStreak({
    required DateTime? lastStudyDate,
    required int currentStreak,
    required DateTime now,
  }) {
    if (lastStudyDate == null) {
      return 1;
    }

    final today = DateTime(now.year, now.month, now.day);
    final lastStudyDay = DateTime(
      lastStudyDate.year,
      lastStudyDate.month,
      lastStudyDate.day,
    );

    final differenceInDays = today.difference(lastStudyDay).inDays;

    if (differenceInDays == 0) {
      // Studied again on the same calendar day: maintain streak (ensure >= 1)
      return currentStreak > 0 ? currentStreak : 1;
    } else if (differenceInDays == 1) {
      // Studied on consecutive calendar day: increment streak!
      return currentStreak + 1;
    } else {
      // Missed at least one calendar day: reset streak to 1
      return 1;
    }
  }

  @override
  Future<List<CardModel>> getCardsForDeck(String deckId, bool isFlashcard) async {
    try {
      final snapshot = await _firestore
          .collection('decks')
          .doc(deckId)
          .collection('cards')
          .get();
      
      final cards = snapshot.docs
          .map((doc) => CardModel.fromMap(doc.id, doc.data(), isFlashcard))
          .toList();

      if (cards.isEmpty) {
        final currentUid = _auth.currentUser?.uid ?? '';
        if (currentUid.isNotEmpty) {
          // Seed initial cards for this deck if none exist yet
          await _seedMockCards(deckId, isFlashcard);
          return await getCardsForDeck(deckId, isFlashcard);
        }
        return [];
      }

      // Overlay user's personal spaced repetition progress if authenticated
      final uid = _auth.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        try {
          final progressSnap = await _firestore
              .collection('users')
              .doc(uid)
              .collection('card_progress')
              .where('deckId', isEqualTo: deckId)
              .get();

          if (progressSnap.docs.isNotEmpty) {
            final progressMap = {
              for (final doc in progressSnap.docs)
                doc.id: CardProgressModel.fromMap(doc.id, doc.data())
            };

            for (final card in cards) {
              final userProg = progressMap[card.id];
              if (userProg != null) {
                card.applyProgress(userProg);
              }
            }
          }
        } catch (progErr) {
          debugPrint('Notice: Could not load user card progress: $progErr');
        }
      }

      return cards;
    } catch (e) {
      debugPrint("Error fetching cards for deck: $e");
      return [];
    }
  }

  @override
  Future<List<CardModel>> getDueCardsForDeck(String deckId, bool isFlashcard, [DateTime? asOf]) async {
    final allCards = await getCardsForDeck(deckId, isFlashcard);
    return SpacedRepetition.filterDueCards(allCards, asOf);
  }

  @override
  Future<void> recordAnswer(CardModel card, bool passed) async {
    SpacedRepetition.calculateNextReview(card, passed);
    
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    try {
      // Save isolated personal progress in users/{uid}/card_progress/{cardId}
      final progress = CardProgressModel(
        cardId: card.id,
        deckId: card.deckId,
        repetitions: card.repetitions,
        easeFactor: card.easeFactor,
        interval: card.interval,
        nextReviewDate: card.nextReviewDate,
        lastReviewedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('card_progress')
          .doc(card.id)
          .set(progress.toMap(), SetOptions(merge: true));

      debugPrint('Personal card progress saved for card ${card.id} (user $uid). Next review in ${card.interval} days');
    } catch (e) {
      debugPrint('Error saving personal card progress in Firestore: $e');
    }
  }

  @override
  Future<List<AchievementModel>> recordSession(SessionModel session) async {
    final uid = session.userId.isNotEmpty ? session.userId : (_auth.currentUser?.uid ?? '');
    if (uid.isEmpty) return [];

    try {
      // 1. Record the session document
      final sessionRef = _firestore.collection('sessions').doc();
      final sessionData = session.toMap();
      sessionData['userId'] = uid;
      await sessionRef.set(sessionData);

      // 2. Fetch current user document to compute streak, score, and evaluate achievements
      final userRef = _firestore.collection('users').doc(uid);
      final userDoc = await userRef.get();
      final now = DateTime.now();

      int currentStreak = 0;
      int currentScore = 0;
      int currentCardsStudied = 0;
      DateTime? lastStudyDate;
      List<String> unlockedIds = [];

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        currentStreak = (data['streakCount'] as num?)?.toInt() ?? 0;
        currentScore = (data['score'] as num?)?.toInt() ?? 0;
        currentCardsStudied = (data['totalCardsStudied'] as num?)?.toInt() ?? 0;
        
        final rawLast = data['lastStudyDate'];
        if (rawLast is Timestamp) {
          lastStudyDate = rawLast.toDate();
        } else if (rawLast is String) {
          lastStudyDate = DateTime.tryParse(rawLast);
        }

        final rawAchievements = data['unlockedAchievements'] as List<dynamic>?;
        if (rawAchievements != null) {
          unlockedIds = rawAchievements.map((e) => e.toString()).toList();
        }
      }

      final newStreak = calculateUpdatedStreak(
        lastStudyDate: lastStudyDate,
        currentStreak: currentStreak,
        now: now,
      );
      final newScore = currentScore + session.xpGained;
      final newCardsStudied = currentCardsStudied + session.totalCards;

      // 3. Evaluate newly unlocked achievements
      final allEvaluated = AchievementModel.evaluateAll(
        streakDays: newStreak,
        cardsStudied: newCardsStudied,
        userRank: 10,
        accuracy: session.accuracy,
        unlockedIds: unlockedIds,
      );

      final newlyUnlocked = allEvaluated
          .where((a) => a.isUnlocked && !unlockedIds.contains(a.id))
          .toList();

      final newlyUnlockedIds = newlyUnlocked.map((a) => a.id).toList();

      // 4. Update user profile in Firestore
      final updateData = <String, dynamic>{
        'score': newScore,
        'totalCardsStudied': newCardsStudied,
        'streakCount': newStreak,
        'lastStudyDate': FieldValue.serverTimestamp(),
      };

      if (newlyUnlockedIds.isNotEmpty) {
        updateData['unlockedAchievements'] = FieldValue.arrayUnion(newlyUnlockedIds);
      }

      if (userDoc.exists) {
        await userRef.update(updateData);
      } else {
        final authUser = _auth.currentUser;
        updateData['name'] = authUser?.displayName ?? 'Learner';
        updateData['displayName'] = authUser?.displayName ?? 'Learner';
        updateData['email'] = authUser?.email ?? '';
        updateData['photoUrl'] = authUser?.photoURL;
        updateData['createdAt'] = FieldValue.serverTimestamp();
        updateData['unlockedAchievements'] = newlyUnlockedIds;
        await userRef.set(updateData);
      }

      debugPrint("Successfully recorded study session: +${session.xpGained} XP, streak: $newStreak for user $uid. New achievements: ${newlyUnlockedIds.join(', ')}");
      notifyListeners();

      return newlyUnlocked;
    } catch (e) {
      debugPrint("Error recording study session in Firestore: $e");
      return [];
    }
  }

  Future<void> _seedMockCards(String deckId, bool isFlashcard) async {
    final currentUid = _auth.currentUser?.uid ?? '';
    if (currentUid.isEmpty) return;

    final batch = _firestore.batch();
    final cardsRef = _firestore.collection('decks').doc(deckId).collection('cards');
    final now = DateTime.now();

    List<CardModel> mockCards;

    if (isFlashcard) {
      mockCards = [
        FlashcardModel(
          id: '',
          deckId: deckId,
          nextReviewDate: now,
          front: 'What is the powerhouse of the cell?',
          back: 'Mitochondria',
        ),
        FlashcardModel(
          id: '',
          deckId: deckId,
          nextReviewDate: now,
          front: 'What is the chemical symbol for Gold?',
          back: 'Au (from Latin: Aurum)',
        ),
        FlashcardModel(
          id: '',
          deckId: deckId,
          nextReviewDate: now,
          front: 'What planet is known as the Red Planet?',
          back: 'Mars (due to iron oxide on its surface)',
        ),
      ];
    } else {
      mockCards = [
        MCQModel(
          id: '',
          deckId: deckId,
          nextReviewDate: now,
          question: 'What is the largest ocean on Earth?',
          options: ['Atlantic Ocean', 'Indian Ocean', 'Arctic Ocean', 'Pacific Ocean'],
          correctIndex: 3,
        ),
        MCQModel(
          id: '',
          deckId: deckId,
          nextReviewDate: now,
          question: 'In what year did the Titanic sink?',
          options: ['1912', '1905', '1920', '1898'],
          correctIndex: 0,
        ),
        MCQModel(
          id: '',
          deckId: deckId,
          nextReviewDate: now,
          question: 'Which element has the atomic number 1?',
          options: ['Helium', 'Hydrogen', 'Oxygen', 'Carbon'],
          correctIndex: 1,
        ),
      ];
    }

    for (final card in mockCards) {
      final docRef = cardsRef.doc();
      final data = card.toMap();
      data['deckId'] = deckId;
      batch.set(docRef, data);
    }

    await batch.commit();
  }
}
