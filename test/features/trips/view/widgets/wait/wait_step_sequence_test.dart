import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/view/widgets/wait/wait_step_sequence.dart';

const _third = Duration(seconds: 3);

void main() {
  late WaitStepSequence seq;
  var finished = 0;

  setUp(() {
    finished = 0;
    seq = WaitStepSequence(stepDuration: _third, onFinished: () => finished++);
  });
  tearDown(() => seq.dispose());

  void check(int lit, int closed) {
    expect(seq.lit, lit, reason: 'passo acceso');
    expect(seq.closed, closed, reason: 'passi chiusi');
  }

  testWidgets(
    'nominale: ogni passo resta acceso per la sua parte, il terzo aspetta',
    (tester) async {
      {
        seq.start();
        check(0, 0);
        await tester.pump(const Duration(milliseconds: 2999));
        check(0, 0);
        await tester.pump(const Duration(milliseconds: 1));
        check(1, 1);
        await tester.pump(_third);
        check(2, 2);
        await tester.pump(const Duration(minutes: 5));
        check(2, 2);
        expect(finished, 0);
        seq.dispose();
      }
    },
  );

  testWidgets('arrivo subito: i minimi di lettura e di riga si rispettano', (
    tester,
  ) async {
    {
      seq.start();
      seq.arrive();
      // Passo 1: acceso 1 s, poi chiuso con la riga.
      await tester.pump(const Duration(milliseconds: 999));
      check(0, 0);
      await tester.pump(const Duration(milliseconds: 1));
      check(0, 1);
      // La riga resta 0,8 s prima del passo 2.
      await tester.pump(const Duration(milliseconds: 799));
      check(0, 1);
      await tester.pump(const Duration(milliseconds: 1));
      check(1, 1);
      await tester.pump(const Duration(seconds: 1));
      check(1, 2);
      await tester.pump(const Duration(milliseconds: 800));
      check(2, 2);
      await tester.pump(const Duration(seconds: 1));
      check(2, 3);
      expect(finished, 0);
      await tester.pump(const Duration(milliseconds: 799));
      expect(finished, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(finished, 1);
      seq.dispose();
    }
  });

  testWidgets('arrivo sul terzo passo già acceso da tempo: chiude e passa', (
    tester,
  ) async {
    {
      seq.start();
      await tester.pump(const Duration(seconds: 8));
      check(2, 2);
      seq.arrive();
      check(2, 3);
      await tester.pump(const Duration(milliseconds: 800));
      expect(finished, 1);
      seq.dispose();
    }
  });

  testWidgets('arrivo a metà di un passo: lo chiude quando ha il minimo', (
    tester,
  ) async {
    {
      seq.start();
      await tester.pump(const Duration(milliseconds: 3500));
      check(1, 1);
      seq.arrive();
      await tester.pump(const Duration(milliseconds: 499));
      check(1, 1);
      await tester.pump(const Duration(milliseconds: 1));
      check(1, 2);
      seq.dispose();
    }
  });

  testWidgets('dispose ferma tutto', (tester) async {
    {
      seq.start();
      seq.arrive();
      seq.dispose();
      await tester.pump(const Duration(minutes: 1));
      expect(finished, 0);
      seq.dispose();
    }
  });
}
