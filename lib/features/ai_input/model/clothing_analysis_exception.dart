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

/// Thrown when the request never reaches the proxy: connessione assente,
/// timeout, DNS, socket chiuso.
///
/// Distinta da [VisionAnalysisException] perché per l'utente è un caso
/// diverso — riprovare ha senso — e perché il messaggio tecnico di queste
/// eccezioni contiene l'URI dell'endpoint, che non deve arrivare a schermo.
final class AnalysisNetworkException extends ClothingAnalysisException {
  const AnalysisNetworkException(super.message);
}

/// Thrown when there is no valid JWT to call the proxy with.
final class AnalysisNotAuthenticatedException
    extends ClothingAnalysisException {
  const AnalysisNotAuthenticatedException(super.message);
}

/// Thrown when the OpenAI response body cannot be parsed into
/// `ClothingAnalysisResult` (unexpected schema or malformed JSON).
final class ResponseParsingException extends ClothingAnalysisException {
  const ResponseParsingException(super.message);
}

/// Thrown when the user has exhausted their lifetime GPT usage cap (HTTP 429).
final class GptLimitExceededException extends ClothingAnalysisException {
  const GptLimitExceededException(super.message);
}
