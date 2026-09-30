import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String id;
  final String userId;
  final String deckId;
  final String deckTitle;
  final String mode; // 'flashcard' or 'mcq'
  final int totalCards;
  final int correctCount;
  final double accuracy;
  final int xpGained;
  final DateTime completedAt;

  SessionModel({
    required this.id,
    required this.userId,
    required this.deckId,
    this.deckTitle = '',
    this.mode = 'flashcard',
    required this.totalCards,
    required this.correctCount,
    double? accuracy,
    int? xpGained,
    required this.completedAt,
  })  : accuracy = accuracy ?? (totalCards == 0 ? 0.0 : (correctCount / totalCards)),
        xpGained = xpGained ?? (correctCount * 10);

  factory SessionModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final total = map['totalCards'] as int? ?? 0;
    final correct = map['correctCount'] as int? ?? 0;
    final acc = (map['accuracy'] as num?)?.toDouble() ?? (total == 0 ? 0.0 : correct / total);

    return SessionModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      deckId: map['deckId'] as String? ?? '',
      deckTitle: map['deckTitle'] as String? ?? '',
      mode: map['mode'] as String? ?? 'flashcard',
      totalCards: total,
      correctCount: correct,
      accuracy: acc,
      xpGained: map['xpGained'] as int? ?? (correct * 10),
      completedAt: parseDate(map['completedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'deckId': deckId,
      'deckTitle': deckTitle,
      'mode': mode,
      'totalCards': totalCards,
      'correctCount': correctCount,
      'accuracy': accuracy,
      'xpGained': xpGained,
      'completedAt': Timestamp.fromDate(completedAt),
    };
  }
}
