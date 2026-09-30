import 'package:cloud_firestore/cloud_firestore.dart';
import 'card_progress_model.dart';

abstract class CardModel {
  final String id;
  final String deckId;
  final String type; // 'flashcard' or 'mcq'
  
  // Spaced Repetition Fields
  DateTime nextReviewDate;
  int repetitions;
  double easeFactor;
  int interval;

  CardModel({
    required this.id,
    required this.deckId,
    required this.type,
    required this.nextReviewDate,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.interval = 0,
  });

  /// Overlays a user's isolated personal spaced repetition progress onto this card.
  void applyProgress(CardProgressModel progress) {
    repetitions = progress.repetitions;
    easeFactor = progress.easeFactor;
    interval = progress.interval;
    nextReviewDate = progress.nextReviewDate;
  }

  Map<String, dynamic> toMap();

  static DateTime parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }

  static CardModel fromMap(String id, Map<String, dynamic> map, [bool? isFlashcardHint]) {
    final type = map['type'] as String?;
    if (type == 'mcq' || (isFlashcardHint != null && !isFlashcardHint && type != 'flashcard')) {
      return MCQModel.fromMap(id, map);
    } else {
      return FlashcardModel.fromMap(id, map);
    }
  }
}

class FlashcardModel extends CardModel {
  final String front;
  final String back;

  FlashcardModel({
    required super.id,
    required super.deckId,
    required super.nextReviewDate,
    required this.front,
    required this.back,
    super.repetitions,
    super.easeFactor,
    super.interval,
  }) : super(type: 'flashcard');

  @override
  Map<String, dynamic> toMap() {
    return {
      'deckId': deckId,
      'type': 'flashcard',
      'front': front,
      'back': back,
      'nextReviewDate': Timestamp.fromDate(nextReviewDate),
      'repetitions': repetitions,
      'easeFactor': easeFactor,
      'interval': interval,
    };
  }

  factory FlashcardModel.fromMap(String id, Map<String, dynamic> map) {
    return FlashcardModel(
      id: id,
      deckId: map['deckId'] as String? ?? '',
      front: map['front'] as String? ?? '',
      back: map['back'] as String? ?? '',
      nextReviewDate: CardModel.parseDate(map['nextReviewDate']),
      repetitions: map['repetitions'] as int? ?? 0,
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      interval: map['interval'] as int? ?? 0,
    );
  }

  FlashcardModel copyWith({
    String? id,
    String? deckId,
    DateTime? nextReviewDate,
    String? front,
    String? back,
    int? repetitions,
    double? easeFactor,
    int? interval,
  }) {
    return FlashcardModel(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      front: front ?? this.front,
      back: back ?? this.back,
      repetitions: repetitions ?? this.repetitions,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
    );
  }
}

class MCQModel extends CardModel {
  final String question;
  final List<String> options;
  final int correctIndex;

  MCQModel({
    required super.id,
    required super.deckId,
    required super.nextReviewDate,
    required this.question,
    required this.options,
    required this.correctIndex,
    super.repetitions,
    super.easeFactor,
    super.interval,
  }) : super(type: 'mcq');

  @override
  Map<String, dynamic> toMap() {
    return {
      'deckId': deckId,
      'type': 'mcq',
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
      'nextReviewDate': Timestamp.fromDate(nextReviewDate),
      'repetitions': repetitions,
      'easeFactor': easeFactor,
      'interval': interval,
    };
  }

  factory MCQModel.fromMap(String id, Map<String, dynamic> map) {
    return MCQModel(
      id: id,
      deckId: map['deckId'] as String? ?? '',
      question: map['question'] as String? ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctIndex: map['correctIndex'] as int? ?? 0,
      nextReviewDate: CardModel.parseDate(map['nextReviewDate']),
      repetitions: map['repetitions'] as int? ?? 0,
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      interval: map['interval'] as int? ?? 0,
    );
  }

  MCQModel copyWith({
    String? id,
    String? deckId,
    DateTime? nextReviewDate,
    String? question,
    List<String>? options,
    int? correctIndex,
    int? repetitions,
    double? easeFactor,
    int? interval,
  }) {
    return MCQModel(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      question: question ?? this.question,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      repetitions: repetitions ?? this.repetitions,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
    );
  }
}
