import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/packlog_gradient.dart';

/// Il passaggio dall'attesa alla valigia: la card dei passi, che parte dal
/// rettangolo [from], si allarga fino a riempire lo schermo mentre il bordo si
/// spegne. Alla fine chiama [onDone]: la pagina d'attesa esce e sotto c'è la
/// valigia. Va messo in uno [Stack] grande come lo schermo.
class WaitHandoff extends StatefulWidget {
  const WaitHandoff({super.key, required this.from, required this.onDone});

  final Rect from;
  final VoidCallback onDone;

  @override
  State<WaitHandoff> createState() => _WaitHandoffState();
}

class _WaitHandoffState extends State<WaitHandoff>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: AppMotion.slow)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onDone();
        })
        ..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final full = Offset.zero & screen;
    final grow = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.emphasized,
    );
    final fill = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.5, curve: AppMotion.standard),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final rect = Rect.lerp(widget.from, full, grow.value)!;
        final radius = AppConstants.cardBorderRadius * (1 - grow.value);
        return Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.groupSurface.withValues(alpha: fill.value),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
                Opacity(
                  opacity: 1 - grow.value,
                  child: PackLogGradientBorder(
                    // Il bordo non accetta un raggio più piccolo del suo spessore.
                    radius: math.max(radius, 1),
                    loops: -1,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
