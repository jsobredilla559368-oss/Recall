import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user's personalized SuperMemo-2 (SM-2) spaced repetition
/// progress for a specific card within a deck.
class CardProgressModel {
  final String cardId;
  final String deckId;
  final int repetitions;
  final double easeFactor;
  final int interval;
  final DateTime nextReviewDate;
  final DateTime? lastReviewedAt;

  const CardProgressModel({
    required this.cardId,
    required this.deckId,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.interval = 0,
    required this.nextReviewDate,
    this.lastReviewedAt,
  });

  factory CardProgressModel.fromMap(String cardId, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return CardProgressModel(
      cardId: cardId,
      deckId: map['deckId'] as String? ?? '',
      repetitions: map['repetitions'] as int? ?? 0,
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      interval: map['interval'] as int? ?? 0,
      nextReviewDate: parseDate(map['nextReviewDate']),
      lastReviewedAt: map['lastReviewedAt'] != null ? parseDate(map['lastReviewedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deckId': deckId,
      'repetitions': repetitions,
      'easeFactor': easeFactor,
      'interval': interval,
      'nextReviewDate': Timestamp.fromDate(nextReviewDate),
      'lastReviewedAt': lastReviewedAt != null
          ? Timestamp.fromDate(lastReviewedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  CardProgressModel copyWith({
    String? cardId,
    String? deckId,
    int? repetitions,
    double? easeFactor,
    int? interval,
    DateTime? nextReviewDate,
    DateTime? lastReviewedAt,
  }) {
    return CardProgressModel(
      cardId: cardId ?? this.cardId,
      deckId: deckId ?? this.deckId,
      repetitions: repetitions ?? this.repetitions,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }
}
