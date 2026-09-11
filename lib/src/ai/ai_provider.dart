/// Optional AI provider contract. The core library remains usable without an AI provider.
abstract interface class AiProvider {
  Future<AiResponse> analyze(AiRequest request);
}

/// A structured request for AI-assisted explanation or prioritization.
class AiRequest {
  const AiRequest({
    required this.category,
    required this.summary,
    required this.evidence,
    this.maxSuggestions = 3,
    this.redactSecrets = true,
  });

  final String category;
  final String summary;
  final List<String> evidence;
  final int maxSuggestions;
  final bool redactSecrets;

  Map<String, dynamic> toJson() => {
    'category': category,
    'summary': summary,
    'evidence': evidence,
    'maxSuggestions': maxSuggestions,
    'redactSecrets': redactSecrets,
  };
}

/// A typed response from an AI provider. This is advisory and should not be trusted blindly.
class AiResponse {
  const AiResponse({
    required this.summary,
    required this.probableCauses,
    required this.suggestions,
    required this.confidence,
  });

  final String summary;
  final List<String> probableCauses;
  final List<String> suggestions;
  final double confidence;

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'probableCauses': probableCauses,
    'suggestions': suggestions,
    'confidence': confidence,
  };
}
