abstract class IAIProvider {
  String get providerName;
  bool get isConfigured;

  Future<String> generateChatCompletion({
    required String systemPrompt,
    required String userPrompt,
    bool jsonMode = true,
  });
}

class AIRateLimitException implements Exception {
  final String provider;
  final String message;

  AIRateLimitException(this.provider, this.message);

  @override
  String toString() => '[$provider Rate Limited (429)]: $message';
}

class AIProviderException implements Exception {
  final String provider;
  final String message;
  final int? statusCode;

  AIProviderException(this.provider, this.message, [this.statusCode]);

  @override
  String toString() => '[$provider Error${statusCode != null ? " ($statusCode)" : ""}]: $message';
}
