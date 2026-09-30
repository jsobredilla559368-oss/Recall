import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final int score;
  final int streakCount;
  final int totalCardsStudied;
  final DateTime? createdAt;
  final DateTime? lastStudyDate;
  final List<String> unlockedAchievements;

  UserModel({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.score = 0,
    this.streakCount = 0,
    this.totalCardsStudied = 0,
    this.createdAt,
    this.lastStudyDate,
    this.unlockedAchievements = const [],
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    DateTime? createdDate;
    if (map['createdAt'] is Timestamp) {
      createdDate = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      createdDate = DateTime.tryParse(map['createdAt'] as String);
    }

    DateTime? lastStudy;
    if (map['lastStudyDate'] is Timestamp) {
      lastStudy = (map['lastStudyDate'] as Timestamp).toDate();
    } else if (map['lastStudyDate'] is String) {
      lastStudy = DateTime.tryParse(map['lastStudyDate'] as String);
    }

    final rawAchievements = map['unlockedAchievements'] as List<dynamic>?;
    final achievements = rawAchievements != null
        ? rawAchievements.map((e) => e.toString()).toList()
        : <String>[];

    return UserModel(
      uid: uid,
      displayName:
          (map['displayName'] ?? map['name']) as String? ?? 'Anonymous',
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      score: (map['score'] as num?)?.toInt() ?? 0,
      streakCount: (map['streakCount'] as num?)?.toInt() ?? 0,
      totalCardsStudied: (map['totalCardsStudied'] as num?)?.toInt() ?? 0,
      createdAt: createdDate,
      lastStudyDate: lastStudy,
      unlockedAchievements: achievements,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'name': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'score': score,
      'streakCount': streakCount,
      'totalCardsStudied': totalCardsStudied,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'lastStudyDate':
          lastStudyDate != null ? Timestamp.fromDate(lastStudyDate!) : null,
      'unlockedAchievements': unlockedAchievements,
    };
  }

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? photoUrl,
    int? score,
    int? streakCount,
    int? totalCardsStudied,
    DateTime? createdAt,
    DateTime? lastStudyDate,
    List<String>? unlockedAchievements,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      score: score ?? this.score,
      streakCount: streakCount ?? this.streakCount,
      totalCardsStudied: totalCardsStudied ?? this.totalCardsStudied,
      createdAt: createdAt ?? this.createdAt,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      unlockedAchievements:
          unlockedAchievements ?? this.unlockedAchievements,
    );
  }
}
