sealed class ClothingAnalysisException implements Exception {
  final String message;
  const ClothingAnalysisException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the Remove.bg background-removal API returns a non-2xx status.
final class BackgroundRemovalException extends ClothingAnalysisException {
  const BackgroundRemovalException(super.message);
}

/// Thrown when the OpenAI Vision API returns a non-2xx status.
final class VisionAnalysisException extends ClothingAnalysisException {
  const VisionAnalysisException(super.message);
}

/// Thrown when the OpenAI response body cannot be parsed into
/// `ClothingAnalysisResult` (unexpected schema or malformed JSON).
final class ResponseParsingException extends ClothingAnalysisException {
  const ResponseParsingException(super.message);
}

/// Thrown when the user has reached their monthly GPT usage cap (HTTP 429).
final class GptLimitExceededException extends ClothingAnalysisException {
  const GptLimitExceededException(super.message);
}
