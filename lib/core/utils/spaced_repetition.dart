import '../../features/study/models/card_model.dart';
import 'dart:math';

class SpacedRepetition {
  /// Applies a binary (Pass/Fail) variation of the SuperMemo-2 (SM-2) algorithm.
  /// Modifies the CardModel in place.
  static void calculateNextReview(CardModel card, bool passed) {
    if (passed) {
      if (card.repetitions == 0) {
        card.interval = 1;
      } else if (card.repetitions == 1) {
        card.interval = 6;
      } else {
        card.interval = (card.interval * card.easeFactor).round();
      }
      card.repetitions++;
      
      // Increase ease factor slightly on pass
      card.easeFactor = card.easeFactor + 0.1;
    } else {
      // Failed: reset repetitions, drastically decrease interval, lower ease factor
      card.repetitions = 0;
      card.interval = 1;
      
      // Decrease ease factor, but don't let it go below 1.3 (SM-2 standard minimum)
      card.easeFactor = max(1.3, card.easeFactor - 0.2);
    }

    card.nextReviewDate = DateTime.now().add(Duration(days: card.interval));
  }

  /// Determines whether a card is due for review based on SM-2 timestamp and repetition count.
  /// A card is due if it has never been studied (repetitions == 0) or if nextReviewDate is on/before asOf.
  static bool isCardDue(CardModel card, [DateTime? asOf]) {
    if (card.repetitions == 0) return true;
    final reference = asOf ?? DateTime.now();
    return card.nextReviewDate.isBefore(reference) ||
        card.nextReviewDate.isAtSameMomentAs(reference);
  }

  /// Filters a list of cards returning only those due for review.
  static List<CardModel> filterDueCards(List<CardModel> cards, [DateTime? asOf]) {
    return cards.where((c) => isCardDue(c, asOf)).toList();
  }

  /// Categorizes cards into 'due', 'learning', and 'mastered' count buckets.
  /// - due: repetitions == 0 or nextReviewDate <= asOf
  /// - learning: repetitions == 1 and not due
  /// - mastered: repetitions >= 2 and not due
  static Map<String, int> getBreakdown(List<CardModel> cards, [DateTime? asOf]) {
    int due = 0;
    int learning = 0;
    int mastered = 0;

    for (final card in cards) {
      if (isCardDue(card, asOf)) {
        due++;
      } else if (card.repetitions == 1) {
        learning++;
      } else {
        mastered++;
      }
    }

    return {
      'due': due,
      'learning': learning,
      'mastered': mastered,
    };
  }
}
