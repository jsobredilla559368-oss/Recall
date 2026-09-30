import 'package:cloud_firestore/cloud_firestore.dart';

class DeckModel {
  final String id;
  final String title;
  final String description;
  final int totalCards;
  final String tag;
  final bool isFlashcard;
  final String author;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPublic;

  DeckModel({
    required this.id,
    required this.title,
    required this.description,
    required this.totalCards,
    required this.tag,
    this.isFlashcard = false,
    required this.author,
    this.createdBy = '',
    required this.createdAt,
    this.updatedAt,
    this.isPublic = true,
  });

  factory DeckModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return DeckModel(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      totalCards: map['totalCards'] as int? ?? 0,
      tag: map['tag'] as String? ?? 'General',
      isFlashcard: map['isFlashcard'] as bool? ?? false,
      author: map['author'] as String? ?? 'Anonymous',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
      isPublic: map['isPublic'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'totalCards': totalCards,
      'tag': tag,
      'isFlashcard': isFlashcard,
      'author': author,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'isPublic': isPublic,
    };
  }

  DeckModel copyWith({
    String? id,
    String? title,
    String? description,
    int? totalCards,
    String? tag,
    bool? isFlashcard,
    String? author,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
  }) {
    return DeckModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      totalCards: totalCards ?? this.totalCards,
      tag: tag ?? this.tag,
      isFlashcard: isFlashcard ?? this.isFlashcard,
      author: author ?? this.author,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}
