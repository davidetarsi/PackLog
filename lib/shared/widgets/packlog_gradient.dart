import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_opacity.dart';

/// I colori del gradiente PackLog: arancio, ambra, rosa. Niente blu né viola.
const kPackLogGradientColors = [
  Color(0xFFFF8A50),
  Color(0xFFFBBF24),
  Color(0xFFF472B6),
];

/// Pendenza del gradiente del bordo: quasi orizzontale (circa 100°).
const _kBorderSlant = 0.18;

/// Bordo col gradiente PackLog attorno a [child].
///
/// Il gradiente scorre di un ciclo ogni [period]. [loops] dice quanti cicli:
/// 0 sta fermo, -1 gira finché il widget è montato. Dopo i giri il bordo
/// resta lì, colorato e fermo, con l'aspetto di quello che non si è mai mosso.
/// Con `MediaQuery.disableAnimations` non parte nessun ticker.
class PackLogGradientBorder extends StatefulWidget {
  const PackLogGradientBorder({
    super.key,
    required this.child,
    required this.radius,
    this.width = 1.5,
    this.loops = 0,
    this.period = const Duration(seconds: 6),
  });

  final Widget child;
  final double radius;
  final double width;

  /// 0 = fermo, -1 = finché è montato, n > 0 = n giri.
  final int loops;
  final Duration period;

  @override
  State<PackLogGradientBorder> createState() => _PackLogGradientBorderState();
}

class _PackLogGradientBorderState extends State<PackLogGradientBorder>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  /// 0 = piena opacità (giri in corso), 1 = a riposo. Finiti i giri passa da
  /// 0 a 1 in [AppMotion.slow] e poi si ferma: nessun ticker resta acceso.
  late final AnimationController _rest;

  /// `true` mentre i giri sono in corso.
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period);
    _rest = AnimationController(vsync: this, value: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PackLogGradientBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
    }
    if (oldWidget.loops != widget.loops || oldWidget.period != widget.period) {
      _controller.stop();
      _moving = false;
      _rest.value = 1;
      _sync();
    }
  }

  /// Avvia o ferma i giri secondo [PackLogGradientBorder.loops] e le
  /// impostazioni di accessibilità. Non riparte se sta già girando.
  void _sync() {
    final shouldMove =
        widget.loops != 0 && !MediaQuery.disableAnimationsOf(context);
    if (!shouldMove) {
      if (_moving) {
        _controller.stop();
        _moving = false;
      }
      // Niente da animare: a riposo subito, senza dissolvenza.
      _rest.value = 1;
      return;
    }
    if (_moving) return;
    _moving = true;
    _rest.value = 0;
    final run = widget.loops < 0
        ? _controller.repeat()
        : _controller.repeat(count: widget.loops);
    // `orCancel` si arrabbia se il controller viene fermato: qui non serve.
    run.whenComplete(() {
      if (!mounted || !_moving) return;
      _moving = false;
      _rest.animateTo(1, duration: AppMotion.slow, curve: AppMotion.standard);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _rest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // Sopra il figlio: il riempimento del figlio non copre il bordo.
      foregroundPainter: _GradientBorderPainter(
        phase: _controller,
        radius: widget.radius,
        width: widget.width,
        rest: _rest,
      ),
      child: widget.child,
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  _GradientBorderPainter({
    required this.phase,
    required this.radius,
    required this.width,
    required this.rest,
  }) : super(repaint: Listenable.merge([phase, rest]));

  final Animation<double> phase;
  final double radius;
  final double width;

  /// 0 = piena opacità, 1 = a riposo ([AppOpacity.restingGradientBorder]).
  final Animation<double> rest;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Un ciclo = il gradiente si sposta della sua lunghezza e ricomincia
    // uguale (primo e ultimo colore coincidono, il tile si ripete).
    final t = phase.value;
    final dx = size.width;
    final dy = size.height * _kBorderSlant;
    final start = Offset(dx * t, dy * t);
    final end = Offset(dx * (t + 1), dy * (t + 1));
    final opacity = 1 - (1 - AppOpacity.restingGradientBorder) * rest.value;
    final colors = [
      for (final c in [...kPackLogGradientColors, kPackLogGradientColors.first])
        c.withValues(alpha: opacity),
    ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = ui.Gradient.linear(start, end, colors, const [
        0,
        0.333,
        0.667,
        1,
      ], TileMode.repeated);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(width / 2),
        Radius.circular(radius - width / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GradientBorderPainter old) =>
      old.radius != radius || old.width != width;
}

/// La scintilla di PackLog: una stella a quattro punte piena, col gradiente.
/// Con [breathing] respira (opacità e scala) finché è montata; con
/// `MediaQuery.disableAnimations` sta ferma.
class PackLogSparkle extends StatefulWidget {
  const PackLogSparkle({super.key, required this.size, this.breathing = false});

  final double size;
  final bool breathing;

  @override
  State<PackLogSparkle> createState() => _PackLogSparkleState();
}

class _PackLogSparkleState extends State<PackLogSparkle>
    with SingleTickerProviderStateMixin {
  static const _breath = Duration(milliseconds: 2400);
  static const _maxScale = 1.12;

  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _breath);
    _curve = CurvedAnimation(parent: _controller, curve: AppMotion.standard);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PackLogSparkle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final shouldRun =
        widget.breathing && !MediaQuery.disableAnimationsOf(context);
    if (shouldRun == _running) return;
    _running = shouldRun;
    if (shouldRun) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final star = SizedBox.square(
      dimension: widget.size,
      child: const CustomPaint(painter: _SparklePainter()),
    );
    if (!widget.breathing) return star;
    return FadeTransition(
      opacity: Tween<double>(
        begin: AppOpacity.sparkleDim,
        end: 1,
      ).animate(_curve),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: _maxScale).animate(_curve),
        child: star,
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter();

  /// La stella nel quadrato 24 x 24: quattro punte, una per lato.
  static const _points = [
    Offset(12, 2),
    Offset(14.2, 8.6),
    Offset(21, 11),
    Offset(14.2, 13.4),
    Offset(12, 20),
    Offset(9.8, 13.4),
    Offset(3, 11),
    Offset(9.8, 8.6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final path = Path()..addPolygon([for (final p in _points) p * scale], true);
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          kPackLogGradientColors,
          const [0, 0.5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_SparklePainter old) => false;
}
