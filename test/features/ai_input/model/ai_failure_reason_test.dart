import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/ai_input/model/ai_failure_reason.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_exception.dart';

void main() {
  group('aiFailureReasonFrom', () {
    test('distingue la rete dall errore del servizio', () {
      // Erano entrambi VisionAnalysisException: il messaggio di rete portava
      // in UI l URI del proxy, per questo ora sono due tipi distinti.
      expect(
        aiFailureReasonFrom(const AnalysisNetworkException('socket closed')),
        AiFailureReason.network,
      );
      expect(
        aiFailureReasonFrom(const VisionAnalysisException('OpenAI 500')),
        AiFailureReason.serviceError,
      );
    });

    test('sessione mancante ha un motivo suo', () {
      expect(
        aiFailureReasonFrom(const AnalysisNotAuthenticatedException('no jwt')),
        AiFailureReason.notAuthenticated,
      );
    });

    test('quota esaurita non è un errore di servizio', () {
      expect(
        aiFailureReasonFrom(const GptLimitExceededException('429')),
        AiFailureReason.limitReached,
      );
    });

    test('parsing e background removal collassano su serviceError', () {
      expect(
        aiFailureReasonFrom(const ResponseParsingException('bad json')),
        AiFailureReason.serviceError,
      );
      expect(
        aiFailureReasonFrom(const BackgroundRemovalException('remove.bg 500')),
        AiFailureReason.serviceError,
      );
    });

    test('qualsiasi altra eccezione cade su unknown', () {
      expect(aiFailureReasonFrom(StateError('boom')), AiFailureReason.unknown);
      expect(aiFailureReasonFrom('una stringa'), AiFailureReason.unknown);
    });
  });

  group('isRetryable', () {
    test('riprovare ha senso solo dove può cambiare qualcosa', () {
      expect(AiFailureReason.network.isRetryable, isTrue);
      expect(AiFailureReason.serviceError.isRetryable, isTrue);
      expect(AiFailureReason.unknown.isRetryable, isTrue);

      // Un "Riprova" qui sarebbe una promessa che il sistema non può mantenere.
      expect(AiFailureReason.limitReached.isRetryable, isFalse);
      expect(AiFailureReason.notAuthenticated.isRetryable, isFalse);
    });
  });

  group('messageKey', () {
    test('ogni motivo ha una chiave distinta sotto ai_import', () {
      final keys = AiFailureReason.values.map((r) => r.messageKey).toList();
      expect(keys.toSet(), hasLength(AiFailureReason.values.length));
      expect(keys.every((k) => k.startsWith('ai_import.')), isTrue);
    });
  });
}
