import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

class UserStudyStats {
  final int totalDecks;
  final int totalCardsStudied;
  final double overallAccuracy; // e.g. 0.91 = 91%

  const UserStudyStats({
    required this.totalDecks,
    required this.totalCardsStudied,
    required this.overallAccuracy,
  });
}

class UserService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<UserModel> _leaderboard = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<UserModel> get leaderboard => _leaderboard;

  UserService() {
    _fetchLeaderboard();
  }

  Future<void> refreshLeaderboard() async {
    await _fetchLeaderboard();
  }

  Stream<UserModel?> streamUserProfile(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserModel.fromMap(snapshot.id, snapshot.data()!);
      }
      return null;
    });
  }

  Future<UserModel?> getUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.id, doc.data()!);
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
    return null;
  }

  Future<UserStudyStats> fetchUserStats(String uid) async {
    if (uid.isEmpty) {
      return const UserStudyStats(
        totalDecks: 0,
        totalCardsStudied: 0,
        overallAccuracy: 0.0,
      );
    }

    try {
      // 1. Fetch user decks count
      final decksSnap = await _firestore
          .collection('decks')
          .where('createdBy', isEqualTo: uid)
          .get();
      final totalDecks = decksSnap.docs.length;

      // 2. Fetch user study sessions
      final sessionsSnap = await _firestore
          .collection('sessions')
          .where('userId', isEqualTo: uid)
          .get();

      int totalCards = 0;
      int totalCorrect = 0;

      for (final doc in sessionsSnap.docs) {
        final data = doc.data();
        final cards = (data['totalCards'] as num?)?.toInt() ?? 0;
        final correct = (data['correctCount'] as num?)?.toInt() ?? 0;
        totalCards += cards;
        totalCorrect += correct;
      }

      // If user doc has totalCardsStudied, take the larger
      final userDoc = await _firestore.collection('users').doc(uid).get();
      int profileCards = 0;
      if (userDoc.exists && userDoc.data() != null) {
        profileCards =
            (userDoc.data()!['totalCardsStudied'] as num?)?.toInt() ?? 0;
      }

      final cardsStudied =
          totalCards > profileCards ? totalCards : profileCards;
      final accuracy =
          totalCards > 0 ? (totalCorrect / totalCards).clamp(0.0, 1.0) : 0.0;

      return UserStudyStats(
        totalDecks: totalDecks,
        totalCardsStudied: cardsStudied,
        overallAccuracy: accuracy,
      );
    } catch (e) {
      debugPrint("Error calculating user stats: $e");
      return const UserStudyStats(
        totalDecks: 0,
        totalCardsStudied: 0,
        overallAccuracy: 0.0,
      );
    }
  }

  Future<void> updateDisplayName(String uid, String newName) async {
    if (uid.isEmpty || newName.trim().isEmpty) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'displayName': newName.trim(),
        'name': newName.trim(),
      });
      await _fetchLeaderboard();
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating display name: $e");
      rethrow;
    }
  }

  Future<void> updatePhotoUrl(String uid, String? photoUrl) async {
    if (uid.isEmpty) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'photoUrl': photoUrl,
      });

      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.uid == uid) {
          if (photoUrl == null || photoUrl.startsWith('http')) {
            await currentUser.updatePhotoURL(photoUrl);
          }
        }
      } catch (authError) {
        debugPrint("Notice: FirebaseAuth updatePhotoURL skipped: $authError");
      }

      await _fetchLeaderboard();
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating photoUrl: $e");
      rethrow;
    }
  }

  Future<void> unlockAchievement(String uid, String achievementId) async {
    await unlockAchievements(uid, [achievementId]);
  }

  Future<void> unlockAchievements(String uid, List<String> achievementIds) async {
    if (uid.isEmpty || achievementIds.isEmpty) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'unlockedAchievements': FieldValue.arrayUnion(achievementIds),
      });
      notifyListeners();
    } catch (e) {
      debugPrint("Error unlocking achievements: $e");
    }
  }

  static final List<UserModel> _previewScholars = [
    UserModel(
      uid: 'scholar_liam',
      displayName: 'Liam Nguyen',
      score: 25120,
      streakCount: 12,
      totalCardsStudied: 1420,
    ),
    UserModel(
      uid: 'scholar_emily',
      displayName: 'Emily Walsh',
      score: 23890,
      streakCount: 8,
      totalCardsStudied: 1150,
    ),
    UserModel(
      uid: 'scholar_david',
      displayName: 'David Kim',
      score: 22150,
      streakCount: 45,
      totalCardsStudied: 980,
    ),
    UserModel(
      uid: 'scholar_maria',
      displayName: 'Maria Garcia',
      score: 20200,
      streakCount: 30,
      totalCardsStudied: 840,
    ),
    UserModel(
      uid: 'scholar_sarah',
      displayName: 'Sarah Chen',
      score: 18450,
      streakCount: 125,
      totalCardsStudied: 1850,
    ),
    UserModel(
      uid: 'scholar_noah',
      displayName: 'Noah Wilson',
      score: 7200,
      streakCount: 3,
      totalCardsStudied: 320,
    ),
  ];

  Future<void> _fetchLeaderboard() async {
    _isLoading = true;

    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('score', descending: true)
          .limit(10)
          .get();

      final users = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();

      if (users.isEmpty) {
        _leaderboard = _previewScholars;
      } else if (users.length < 5) {
        // Merge real users with preview scholars avoiding duplicate UIDs
        final existingUids = users.map((u) => u.uid).toSet();
        final fillers = _previewScholars.where((s) => !existingUids.contains(s.uid));
        final combined = [...users, ...fillers];
        combined.sort((a, b) => b.score.compareTo(a.score));
        _leaderboard = combined.take(10).toList();
      } else {
        _leaderboard = users;
      }
    } catch (e) {
      debugPrint("Error fetching leaderboard: $e. Falling back to preview scholars.");
      _leaderboard = _previewScholars;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// App Store Guideline 5.1.1 compliant account purge.
  /// Anonymizes public decks, deletes private decks and their cards,
  /// purges card progress, clears session logs, removes stored avatar,
  /// and deletes the root user document.
  Future<void> deleteAccountCascade(String uid, {IStorageService? storageService}) async {
    if (uid.isEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Handle user's decks
      final decksSnap = await _firestore
          .collection('decks')
          .where('createdBy', isEqualTo: uid)
          .get();

      for (final deckDoc in decksSnap.docs) {
        final data = deckDoc.data();
        final isPublic = data['isPublic'] as bool? ?? false;

        if (isPublic) {
          // Anonymize public deck to preserve community study value
          await deckDoc.reference.update({
            'createdBy': 'deleted_user',
            'author': 'Anonymous Scholar',
          });
          debugPrint('[UserService] Anonymized public deck ${deckDoc.id}');
        } else {
          // Hard delete private deck and all cards inside subcollection
          final cardsSnap = await deckDoc.reference.collection('cards').get();
          final batch = _firestore.batch();
          for (final cardDoc in cardsSnap.docs) {
            batch.delete(cardDoc.reference);
          }
          batch.delete(deckDoc.reference);
          await batch.commit();
          debugPrint('[UserService] Deleted private deck ${deckDoc.id} and ${cardsSnap.docs.length} cards.');
        }
      }

      // 2. Delete user's isolated card progress subcollection
      final progressSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('card_progress')
          .get();

      if (progressSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in progressSnap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint('[UserService] Purged ${progressSnap.docs.length} card progress records for $uid.');
      }

      // 3. Delete user's study sessions
      final sessionsSnap = await _firestore
          .collection('sessions')
          .where('userId', isEqualTo: uid)
          .get();

      if (sessionsSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in sessionsSnap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint('[UserService] Purged ${sessionsSnap.docs.length} sessions for $uid.');
      }

      // 4. Delete user's avatar in Storage if present
      if (storageService != null) {
        try {
          await storageService.deleteFile('users/$uid/avatar.jpg');
        } catch (_) {}
      }

      // 5. Delete root user document
      await _firestore.collection('users').doc(uid).delete();
      debugPrint('[UserService] Deleted root user document users/$uid.');

      await _fetchLeaderboard();
    } catch (e) {
      debugPrint('[UserService] Error during deleteAccountCascade: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
