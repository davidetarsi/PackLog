import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../shared/theme/app_motion.dart';

/// Quanti sono i passi dell'attesa.
const kWaitSteps = 3;

/// La sequenza dei tre passi dell'attesa: quale è acceso e quanti sono chiusi
/// (con la riga del dato vero).
///
/// A tempo normale ogni passo resta acceso per [stepDuration] (un terzo del
/// tempo medio) e il successivo si accende subito; l'ultimo resta acceso fino
/// a [arrive]. Quando la valigia è già arrivata i passi rimasti si susseguono
/// con i minimi di [AppMotion.stepReadMin] (passo acceso) e
/// [AppMotion.stepResultMin] (riga visibile prima del passo dopo); finita
/// l'ultima riga parte [onFinished].
class WaitStepSequence extends ChangeNotifier {
  WaitStepSequence({required this.stepDuration, required this.onFinished});

  final Duration stepDuration;
  final VoidCallback onFinished;

  /// Passo acceso: da 0 a [kWaitSteps] - 1.
  int get lit => _lit;

  /// Passi chiusi, con la spunta e la riga.
  int get closed => _closed;

  int _lit = 0;
  int _closed = 0;
  bool _arrived = false;
  bool _readDone = false;
  bool _turnDone = false;
  bool _disposed = false;
  final List<Timer> _timers = [];

  void start() => _light(0);

  /// La valigia è arrivata: da qui i passi rimasti vanno coi minimi.
  void arrive() {
    if (_arrived || _disposed) return;
    _arrived = true;
    _tryClose();
  }

  void _light(int step) {
    _lit = step;
    _readDone = false;
    _turnDone = false;
    notifyListeners();
    _later(AppMotion.stepReadMin, () {
      _readDone = true;
      _tryClose();
    });
    if (step < kWaitSteps - 1) {
      _later(stepDuration, () {
        _turnDone = true;
        _tryClose();
      });
    }
  }

  /// Chiude il passo acceso se ha avuto il suo tempo: quello nominale o,
  /// con la valigia già arrivata, il minimo di lettura.
  void _tryClose() {
    if (_closed > _lit || !_readDone) return;
    final last = _lit == kWaitSteps - 1;
    if (!_arrived && (last || !_turnDone)) return;
    _closed = _lit + 1;
    notifyListeners();
    if (last) {
      _later(AppMotion.stepResultMin, onFinished);
    } else if (_arrived) {
      _later(AppMotion.stepResultMin, () => _light(_lit + 1));
    } else {
      _light(_lit + 1);
    }
  }

  void _later(Duration delay, VoidCallback action) {
    _timers.add(
      Timer(delay, () {
        if (!_disposed) action();
      }),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
