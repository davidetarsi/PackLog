import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Barra di avanzamento ibrida per l'analisi AI.
///
/// **Perché non è né determinata né indeterminata.**
/// Il tempo di risposta di GPT per foto non è noto a priori, ma il numero di
/// foto sì. Una barra che avanza solo sui completamenti reali salterebbe
/// 0 → 33 → 66 → 100 con lunghe pause immobili, che si leggono come un blocco.
/// Uno spinner indeterminato non direbbe nulla sulla durata.
///
/// Qui i due segnali si combinano: i confini dei segmenti sono informazione
/// vera (foto k completata ⇒ k/n), mentre dentro il segmento si interpola su
/// una stima.
///
/// **Perché non si ferma a un valore fisso.**
/// L'interpolazione è asintotica: `1 - e^(-k·t/stima)` con k ≈ 2.3, quindi al
/// tempo stimato il segmento è al 90% e da lì continua a strisciare senza mai
/// toccare il bordo. Una barra parcheggiata su un numero promette imminenza e
/// non mantiene; una che rallenta dice onestamente "ci sta mettendo di più".
/// All'arrivo della risposta il valore scatta al bordo del segmento.
///
/// Il valore mostrato è monotòno per costruzione: non torna mai indietro.
class AiAnalysisProgress extends StatefulWidget {
  /// Indice 1-based della foto in lavorazione (0 = non ancora iniziato).
  final int processingIndex;

  /// Numero totale di foto del lotto.
  final int totalImages;

  /// Durata media stimata per foto, in millisecondi.
  final int avgPhotoMs;

  const AiAnalysisProgress({
    super.key,
    required this.processingIndex,
    required this.totalImages,
    required this.avgPhotoMs,
  });

  @override
  State<AiAnalysisProgress> createState() => _AiAnalysisProgressState();
}

class _AiAnalysisProgressState extends State<AiAnalysisProgress>
    with SingleTickerProviderStateMixin {
  /// Con k = ln(10) il segmento raggiunge il 90% al tempo stimato.
  static const _k = 2.302585;

  late final Ticker _ticker;
  Duration _segmentElapsed = Duration.zero;
  Duration _lastTick = Duration.zero;
  int _segmentIndex = 0;
  double _shown = 0;

  @override
  void initState() {
    super.initState();
    _segmentIndex = widget.processingIndex;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant AiAnalysisProgress old) {
    super.didUpdateWidget(old);
    // Nuova foto in lavorazione: il segmento riparte da capo.
    if (widget.processingIndex != _segmentIndex) {
      _segmentIndex = widget.processingIndex;
      _segmentElapsed = Duration.zero;
      _lastTick = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    if (_lastTick == Duration.zero) {
      _lastTick = now;
      return;
    }
    setState(() {
      _segmentElapsed += now - _lastTick;
      _lastTick = now;
    });
  }

  double get _value {
    final total = widget.totalImages;
    if (total <= 0 || widget.processingIndex <= 0) return 0;

    final segmentSize = 1 / total;
    final completed = (widget.processingIndex - 1) * segmentSize;

    final estimate = math.max(widget.avgPhotoMs, 1);
    final t = _segmentElapsed.inMilliseconds / estimate;
    final withinSegment = 1 - math.exp(-_k * t);

    final target = (completed + segmentSize * withinSegment).clamp(0.0, 1.0);
    // Monotonìa: un cambio di stima o un rebuild non devono far arretrare.
    if (target > _shown) _shown = target;
    return _shown;
  }

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(value: _value, minHeight: 6);
  }
}
