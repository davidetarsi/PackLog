import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Contenitore con bordo tratteggiato: segnala uno "spazio vuoto, aggiungi
/// qui" senza usare colore d'accento.
class DsDashedBox extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color? color;

  const DsDashedBox({
    super.key,
    required this.child,
    this.radius = AppConstants.cardBorderRadius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // Sopra il figlio: un riempimento del figlio non copre il tratteggio.
      foregroundPainter: _DashedRRectPainter(
        color: color ?? Theme.of(context).colorScheme.outline,
        radius: radius,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRRectPainter({required this.color, required this.radius});

  static const _dash = 6.0;
  static const _gap = 4.0;
  static const _stroke = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect.deflate(_stroke / 2),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
