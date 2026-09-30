import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'ai_provider.dart';

class GroqAIProvider implements IAIProvider {
  final http.Client _client;

  GroqAIProvider({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get providerName => 'Groq (Llama-3.3)';

  String get _apiKey => dotenv.env['GROQ_API_KEY']?.trim() ?? '';
  String get _model => dotenv.env['GROQ_MODEL']?.trim() ?? 'llama-3.3-70b-versatile';

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  static const String _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  @override
  Future<String> generateChatCompletion({
    required String systemPrompt,
    required String userPrompt,
    bool jsonMode = true,
  }) async {
    if (!isConfigured) {
      throw AIProviderException('Groq', 'GROQ_API_KEY is not configured in .env');
    }

    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    };

    final body = {
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': 0.3,
      'max_tokens': 8192,
    };

    if (jsonMode) {
      body['response_format'] = {'type': 'json_object'};
    }

    try {
      debugPrint('[Groq] Sending request to $_endpoint using model $_model...');
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final content = choices[0]['message']?['content'] as String? ?? '';
          debugPrint('[Groq] Received successful response (${content.length} chars).');
          return content;
        }
        throw AIProviderException('Groq', 'Empty completion choices received from API');
      } else if (response.statusCode == 429) {
        throw AIRateLimitException('Groq', response.body);
      } else {
        throw AIProviderException('Groq', response.body, response.statusCode);
      }
    } on AIRateLimitException {
      rethrow;
    } catch (e) {
      if (e is AIProviderException) rethrow;
      debugPrint('[Groq] Request failed: $e');
      throw AIProviderException('Groq', e.toString());
    }
  }
}
