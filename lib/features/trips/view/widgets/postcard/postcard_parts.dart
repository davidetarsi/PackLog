import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/app_opacity.dart';
import '../../../../../shared/theme/app_spacing.dart';
import '../../../../../shared/theme/surface_colors.dart';
import '../../../../../shared/theme/app_text_styles.dart';

/// Inchiostro del timbro: un velo sul colore del testo, più spento del testo.
const double _stampInkOpacity = 0.7;

/// Carta della cartolina: superficie di gruppo, angoli contenuti, bordo
/// sottile e ombra leggera come la barra flottante.
class PostcardPaper extends StatelessWidget {
  final Widget? child;

  /// Padding interno. Di default `spacingLg` su tutti i lati.
  final EdgeInsetsGeometry? padding;

  const PostcardPaper({super.key, this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppConstants.badgeBorderRadius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: AppOpacity.shadow),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        padding: padding ?? EdgeInsets.all(context.spacingLg),
        decoration: BoxDecoration(
          color: context.groupSurface,
          borderRadius: radius,
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: AppOpacity.mutedBorder),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Francobollo: carta con i bordi "mangiati" da semicerchi e una cornice
/// interna. Il contenuto è centrato.
class PostageStamp extends StatelessWidget {
  final Size size;
  final Widget child;

  const PostageStamp({super.key, required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CustomPaint(
      size: size,
      painter: _StampPainter(
        color: cs.surfaceContainerHigh,
        border: cs.outlineVariant,
      ),
      child: SizedBox.fromSize(
        size: size,
        child: Center(child: child),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  static const double _biteRadius = 3.5;
  static const double _biteStep = 10;
  static const double _frameInset = 8;
  static const double _frameStroke = 1;

  final Color color;
  final Color border;

  const _StampPainter({required this.color, required this.border});

  @override
  void paint(Canvas canvas, Size size) {
    var shape = Path()..addRect(Offset.zero & size);
    final bites = Path();
    for (var x = _biteStep / 2; x < size.width; x += _biteStep) {
      bites
        ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: _biteRadius))
        ..addOval(
          Rect.fromCircle(center: Offset(x, size.height), radius: _biteRadius),
        );
    }
    for (var y = _biteStep / 2; y < size.height; y += _biteStep) {
      bites
        ..addOval(Rect.fromCircle(center: Offset(0, y), radius: _biteRadius))
        ..addOval(
          Rect.fromCircle(center: Offset(size.width, y), radius: _biteRadius),
        );
    }
    shape = Path.combine(PathOperation.difference, shape, bites);
    canvas.drawPath(shape, Paint()..color = color);

    canvas.drawRect(
      (Offset.zero & size).deflate(_frameInset),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = _frameStroke,
    );
  }

  @override
  bool shouldRepaint(covariant _StampPainter old) =>
      old.color != color || old.border != border;
}

/// Timbro postale tondo: marchio, data `d MMM` in maiuscolo e anno. Inclinato
/// appena, come se fosse appoggiato sopra il francobollo.
class Postmark extends StatelessWidget {
  static const double _tilt = -0.3;

  final DateTime date;
  final double size;

  const Postmark({super.key, required this.date, required this.size});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final locale = context.locale.toString();
    final ink = cs.onSurfaceVariant;

    return Transform.rotate(
      angle: _tilt,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: ink.withValues(alpha: _stampInkOpacity),
            width: AppConstants.selectedBorderWidth,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              child: Text(
                'trips.postcard.postmark_brand'.tr(),
                style: tt.labelSmall?.copyWith(color: ink, letterSpacing: 1),
              ),
            ),
            FittedBox(
              child: Text(
                DateFormat('d MMM', locale).format(date).toUpperCase(),
                style: tt.labelLarge?.postcard.copyWith(color: ink),
              ),
            ),
            FittedBox(
              child: Text(
                DateFormat('yyyy', locale).format(date),
                style: tt.labelSmall?.copyWith(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le quattro onde del timbro postale che "annullano" un francobollo.
class CancelWaves extends StatelessWidget {
  final Size size;

  const CancelWaves({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CustomPaint(
      size: size,
      painter: _CancelWavesPainter(color: cs.onSurfaceVariant),
    );
  }
}

class _CancelWavesPainter extends CustomPainter {
  static const int _waveCount = 4;
  static const double _firstWave = 0.3;
  static const double _waveSpacing = 0.13;
  static const double _amplitude = 2.2;
  static const double _wavelength = 5;
  static const double _stroke = 1.4;

  final Color color;

  const _CancelWavesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;

    for (var k = 0; k < _waveCount; k++) {
      final y = size.height * (_firstWave + _waveSpacing * k);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 2) {
        path.lineTo(x, y + math.sin(x / _wavelength) * _amplitude);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CancelWavesPainter old) => old.color != color;
}
