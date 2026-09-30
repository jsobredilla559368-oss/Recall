import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/services/ai/ai_provider.dart';
import 'package:recall/core/services/ai_service.dart';
import 'package:recall/features/study/models/card_model.dart';

class MockSuccessProvider implements IAIProvider {
  final String _name;
  final String _response;

  MockSuccessProvider(this._name, this._response);

  @override
  String get providerName => _name;

  @override
  bool get isConfigured => true;

  @override
  Future<String> generateChatCompletion({
    required String systemPrompt,
    required String userPrompt,
    bool jsonMode = true,
  }) async {
    return _response;
  }
}

class MockRateLimitedProvider implements IAIProvider {
  final String _name;

  MockRateLimitedProvider(this._name);

  @override
  String get providerName => _name;

  @override
  bool get isConfigured => true;

  @override
  Future<String> generateChatCompletion({
    required String systemPrompt,
    required String userPrompt,
    bool jsonMode = true,
  }) async {
    throw AIRateLimitException(_name, 'HTTP 429: Too Many Requests');
  }
}

void main() {
  group('AIService JSON Parsing & Synthesis Tests', () {
    test('Parses valid Flashcards JSON output correctly from Groq', () async {
      const mockJson = '''
      {
        "cards": [
          {"front": "What is Flutter?", "back": "UI toolkit by Google"},
          {"front": "What is Dart?", "back": "Client-optimized language"}
        ]
      }
      ''';

      final provider = MockSuccessProvider('Groq (Llama-3.3)', mockJson);
      final aiService = AIService(aiProvider: provider);

      final result = await aiService.generateDeckFromText(
        title: 'Flutter Basics',
        text: '',
        tag: 'Tech',
        isFlashcard: true,
        cardCount: 2,
      );

      expect(result.cards.length, 2);
      expect(result.cards.first, isA<FlashcardModel>());
      final card = result.cards.first as FlashcardModel;
      expect(card.front, 'What is Flutter?');
      expect(card.back, 'UI toolkit by Google');
      expect(result.providerUsed, 'Groq (Llama-3.3)');
    });

    test('Parses valid MCQ JSON output correctly from Groq', () async {
      const mockJson = '''
      {
        "cards": [
          {
            "question": "Which widget is stateless?",
            "options": ["StatelessWidget", "StatefulWidget", "InheritedNotifier", "ChangeNotifier"],
            "correctIndex": 0
          }
        ]
      }
      ''';

      final provider = MockSuccessProvider('Groq (Llama-3.3)', mockJson);
      final aiService = AIService(aiProvider: provider);

      final result = await aiService.generateDeckFromText(
        title: 'Flutter Widgets',
        text: '',
        tag: 'Tech',
        isFlashcard: false,
        cardCount: 1,
      );

      expect(result.cards.length, 1);
      expect(result.cards.first, isA<MCQModel>());
      final mcq = result.cards.first as MCQModel;
      expect(mcq.question, 'Which widget is stateless?');
      expect(mcq.options.length, 4);
      expect(mcq.correctIndex, 0);
    });

    test('Heuristic synthesis engages safely when provider fails or is rate limited', () async {
      final provider = MockRateLimitedProvider('Groq');
      final aiService = AIService(aiProvider: provider);

      final result = await aiService.generateDeckFromText(
        title: 'Photosynthesis',
        text: '',
        tag: 'Biology',
        isFlashcard: true,
        cardCount: 3,
      );

      expect(result.cards.isNotEmpty, true);
      expect(result.providerUsed, 'Heuristic Synthesizer');
    });

    test('Synthesis scales up to large card counts (e.g. 50 and 100)', () async {
      final provider = MockRateLimitedProvider('Groq');
      final aiService = AIService(aiProvider: provider);

      final result50 = await aiService.generateDeckFromText(
        title: 'Quantum Physics',
        text: '',
        tag: 'Physics',
        isFlashcard: true,
        cardCount: 50,
      );
      expect(result50.cards.length, 50);

      final result100 = await aiService.generateDeckFromText(
        title: 'World History',
        text: '',
        tag: 'History',
        isFlashcard: false,
        cardCount: 100,
      );
      expect(result100.cards.length, 100);
    });
  });
}
