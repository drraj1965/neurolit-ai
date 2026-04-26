class AiConfigurationRequiredException implements Exception {
  final String message;

  AiConfigurationRequiredException([
    this.message = 'No active AI provider is configured.',
  ]);

  @override
  String toString() => message;
}

class AiProviderValidationException implements Exception {
  final String message;

  AiProviderValidationException(this.message);

  @override
  String toString() => message;
}

class AiProviderUnsupportedException implements Exception {
  final String message;

  AiProviderUnsupportedException(this.message);

  @override
  String toString() => message;
}
