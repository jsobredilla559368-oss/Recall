import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../features/decks/models/deck_model.dart';
import '../../features/study/models/card_model.dart';
import 'ai/ai_provider.dart';
import 'ai/groq_provider.dart';
import 'ai/ai_prompts.dart';

class AIGeneratedDeckResult {
  final DeckModel deck;
  final List<CardModel> cards;
  final String providerUsed;

  AIGeneratedDeckResult({
    required this.deck,
    required this.cards,
    this.providerUsed = 'AI Engine',
  });
}

abstract class IAIService {
  Future<AIGeneratedDeckResult> generateDeckFromText({
    required String title,
    required String text,
    required String tag,
    bool isFlashcard = true,
    int cardCount = 5,
  });

  Future<AIGeneratedDeckResult> generateDeckFromFile({
    required String title,
    required String fileUrl,
    required String tag,
    bool isFlashcard = false,
    int cardCount = 5,
  });
}

class AIService extends ChangeNotifier implements IAIService {
  final IAIProvider _aiProvider;

  AIService({IAIProvider? aiProvider})
      : _aiProvider = aiProvider ?? GroqAIProvider();

  String get activeProviderName => _aiProvider.providerName;
  bool get hasConfiguredApiKey => _aiProvider.isConfigured;

  @override
  Future<AIGeneratedDeckResult> generateDeckFromText({
    required String title,
    required String text,
    required String tag,
    bool isFlashcard = true,
    int cardCount = 5,
  }) async {
    final now = DateTime.now();
    List<CardModel> generatedCards = [];
    String engineUsed = 'Local Heuristic';

    if (_aiProvider.isConfigured) {
      try {
        final systemPrompt = isFlashcard
            ? AIPrompts.flashcardsSystemPrompt(cardCount)
            : AIPrompts.mcqSystemPrompt(cardCount);

        final safeText = text.trim().length > 30000
            ? '${text.trim().substring(0, 30000)}\n[Note: Source material condensed for optimal AI synthesis]'
            : text.trim();

        final userPrompt = AIPrompts.userPrompt(
          title: title,
          text: safeText,
          tag: tag,
          count: cardCount,
        );

        final rawJson = await _aiProvider.generateChatCompletion(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          jsonMode: true,
        );

        engineUsed = _aiProvider.providerName;
        generatedCards = _parseCardsFromJson(rawJson, isFlashcard, now);
        debugPrint('[AIService] Successfully parsed ${generatedCards.length} cards from $engineUsed.');
      } catch (e) {
        debugPrint('[AIService] Remote AI generation error: $e. Falling back to heuristic synthesis.');
      }
    } else {
      debugPrint('[AIService] No AI API keys configured. Using local heuristic synthesis.');
    }

    // If remote AI produced fewer than requested or encountered an error, augment with heuristics
    if (generatedCards.isEmpty) {
      if (isFlashcard) {
        generatedCards = _generateFallbackFlashcards(title, text, now, cardCount);
      } else {
        generatedCards = _generateFallbackMCQs(title, text, now, cardCount);
      }
      engineUsed = 'Heuristic Synthesizer';
    }

    final deck = DeckModel(
      id: '',
      title: title.trim(),
      description: text.trim().isNotEmpty
          ? (text.length > 120 ? '${text.substring(0, 117)}...' : text)
          : 'AI-generated study deck for $title ($engineUsed).',
      totalCards: generatedCards.length,
      tag: tag.trim().isEmpty ? 'General' : tag.trim(),
      isFlashcard: isFlashcard,
      author: 'AI ($engineUsed)',
      createdAt: now,
      isPublic: false,
    );

    return AIGeneratedDeckResult(
      deck: deck,
      cards: generatedCards,
      providerUsed: engineUsed,
    );
  }

  @override
  Future<AIGeneratedDeckResult> generateDeckFromFile({
    required String title,
    required String fileUrl,
    required String tag,
    bool isFlashcard = false,
    int cardCount = 5,
  }) async {
    return generateDeckFromText(
      title: title,
      text: fileUrl,
      tag: tag,
      isFlashcard: isFlashcard,
      cardCount: cardCount,
    );
  }

  List<CardModel> _parseCardsFromJson(String rawJson, bool isFlashcard, DateTime now) {
    try {
      // Clean possible markdown code fences (```json ... ```)
      var clean = rawJson.trim();
      if (clean.startsWith('```json')) {
        clean = clean.substring(7);
      } else if (clean.startsWith('```')) {
        clean = clean.substring(3);
      }
      if (clean.endsWith('```')) {
        clean = clean.substring(0, clean.length - 3);
      }
      clean = clean.trim();

      final decoded = jsonDecode(clean) as Map<String, dynamic>;
      final cardList = decoded['cards'] as List<dynamic>?;
      if (cardList == null || cardList.isEmpty) return [];

      final List<CardModel> cards = [];

      for (final item in cardList) {
        if (item is! Map<String, dynamic>) continue;

        if (isFlashcard) {
          final front = item['front']?.toString().trim() ?? '';
          final back = item['back']?.toString().trim() ?? '';
          if (front.isNotEmpty && back.isNotEmpty) {
            cards.add(FlashcardModel(
              id: '',
              deckId: '',
              nextReviewDate: now,
              front: front,
              back: back,
            ));
          }
        } else {
          final question = item['question']?.toString().trim() ?? '';
          final rawOptions = item['options'] as List<dynamic>? ?? [];
          final options = rawOptions.map((o) => o.toString().trim()).where((o) => o.isNotEmpty).toList();
          final correctIdx = (item['correctIndex'] as num?)?.toInt() ?? 0;

          if (question.isNotEmpty && options.length >= 2) {
            cards.add(MCQModel(
              id: '',
              deckId: '',
              nextReviewDate: now,
              question: question,
              options: options,
              correctIndex: (correctIdx >= 0 && correctIdx < options.length) ? correctIdx : 0,
            ));
          }
        }
      }

      return cards;
    } catch (e) {
      debugPrint('[AIService] Failed to parse AI JSON output: $e\nRaw: $rawJson');
      return [];
    }
  }

  List<CardModel> _generateFallbackFlashcards(String title, String text, DateTime now, int count) {
    final List<FlashcardModel> cards = [];

    // Parse delimiter lines if user provided any
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    for (final line in lines) {
      if (line.contains(':') || line.contains(' - ')) {
        final separator = line.contains(':') ? ':' : ' - ';
        final parts = line.split(separator);
        if (parts.length >= 2 && parts[0].trim().isNotEmpty && parts[1].trim().isNotEmpty) {
          cards.add(FlashcardModel(
            id: '',
            deckId: '',
            nextReviewDate: now,
            front: parts[0].trim(),
            back: parts.sublist(1).join(separator).trim(),
          ));
        }
      }
    }

    // Augment with smart conceptual cards if below count
    final concepts = [
      (
        'What is the core definition of $title?',
        text.trim().isNotEmpty
            ? 'Key premise: ${text.length > 90 ? text.substring(0, 90) : text}...'
            : 'Fundamental principles and foundational concepts governing $title.',
      ),
      (
        'What are the primary advantages / significance of $title?',
        'Enhances cognitive retention, modular thinking, and real-world domain mastery.',
      ),
      (
        'How is $title commonly applied in practice?',
        'Applied through iterative practice, systematic breakdown, and real-time active recall.',
      ),
      (
        'What are common pitfalls to avoid when studying $title?',
        'Passive reading without self-testing, skipping foundational principles, and cramming without spacing.',
      ),
      (
        'How does $title relate to broader knowledge systems?',
        'Serves as a vital building block that integrates with adjacent topics for deep contextual understanding.',
      ),
    ];

    int i = 0;
    while (cards.length < count) {
      final index = i % concepts.length;
      final cycle = (i ~/ concepts.length) + 1;
      final prefix = cycle > 1 ? 'Part $cycle: ' : '';
      cards.add(FlashcardModel(
        id: '',
        deckId: '',
        nextReviewDate: now,
        front: '$prefix${concepts[index].$1}',
        back: concepts[index].$2,
      ));
      i++;
    }

    return cards.take(count).toList();
  }

  List<CardModel> _generateFallbackMCQs(String title, String text, DateTime now, int count) {
    final questions = [
      MCQModel(
        id: '',
        deckId: '',
        nextReviewDate: now,
        question: 'Which statement most accurately characterizes "$title"?',
        options: [
          'A structured methodology focused on optimal understanding and application',
          'An obsolete theoretical concept with no practical utility',
          'A strictly hardware-based protocol used exclusively in networking',
          'A random guessing mechanism with no systematic rules',
        ],
        correctIndex: 0,
      ),
      MCQModel(
        id: '',
        deckId: '',
        nextReviewDate: now,
        question: 'What is the recommended approach when mastering topics in $title?',
        options: [
          'Passive reading without self-testing',
          'Active recall combined with spaced repetition cycles',
          'Memorizing raw data without conceptual comprehension',
          'Skipping foundational principles',
        ],
        correctIndex: 1,
      ),
      MCQModel(
        id: '',
        deckId: '',
        nextReviewDate: now,
        question: 'When evaluating success in $title, which metric is most meaningful?',
        options: [
          'Volume of pages skimmed',
          'Long-term retention and high retrieval accuracy',
          'Speed of initial guessing',
          'Total hours spent multitasking',
        ],
        correctIndex: 1,
      ),
      MCQModel(
        id: '',
        deckId: '',
        nextReviewDate: now,
        question: 'Which cognitive technique directly reinforces memory retention in $title?',
        options: [
          'Testing yourself through deliberate retrieval practice',
          'Rereading highlighted text repeatedly',
          'Waiting until the night before an exam to study',
          'Relying solely on intuition without practice',
        ],
        correctIndex: 0,
      ),
      MCQModel(
        id: '',
        deckId: '',
        nextReviewDate: now,
        question: 'In the context of $title, what role does spaced repetition play?',
        options: [
          'Interrupts forgetting curves by scheduling reviews at expanding intervals',
          'Compresses all review into a single intense session',
          'Replaces active thinking with automated flashcard scripts',
          'Eliminates the need to understand core concepts',
        ],
        correctIndex: 0,
      ),
    ];

    final List<CardModel> result = [];
    int i = 0;
    while (result.length < count) {
      final template = questions[i % questions.length];
      final cycle = (i ~/ questions.length) + 1;
      final prefix = cycle > 1 ? '[Set $cycle] ' : '';
      result.add(MCQModel(
        id: '',
        deckId: '',
        nextReviewDate: now,
        question: '$prefix${template.question}',
        options: List<String>.from(template.options),
        correctIndex: template.correctIndex,
      ));
      i++;
    }

    return result.take(count).toList();
  }
}
