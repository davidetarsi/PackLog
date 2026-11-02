import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';

/// Un volo: [child] parte dal rettangolo [from] (coordinate dello schermo) e
/// atterra sul widget che ha la chiave [to].
class ItemFlight {
  const ItemFlight({required this.from, required this.to, required this.child});

  final Rect from;
  final GlobalKey to;
  final Widget child;
}

/// Il rettangolo di [key] sullo schermo, o `null` se non è sul foglio.
Rect? _screenRect(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Porta ogni figlio da `from` al rettangolo di `to` con [AppMotion.slow],
/// sopra a tutto (un [OverlayEntry]), poi lo toglie. Torna a volo finito.
///
/// Chi non ha ancora un bersaglio sul foglio è saltato. Con le animazioni di
/// sistema disattivate torna subito. Non sa niente di cosa vola.
Future<void> flyItems(
  BuildContext context, {
  required List<ItemFlight> flights,
}) async {
  if (MediaQuery.disableAnimationsOf(context)) return;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final legs = <_Leg>[];
  for (final flight in flights) {
    final target = _screenRect(flight.to);
    if (target != null) {
      legs.add(_Leg(RectTween(begin: flight.from, end: target), flight.child));
    }
  }
  if (legs.isEmpty) return;

  final done = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlightLayer(
      legs: legs,
      onDone: () {
        entry.remove();
        entry.dispose();
        done.complete();
      },
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class _Leg {
  const _Leg(this.path, this.child);

  final RectTween path;
  final Widget child;
}

class _FlightLayer extends StatefulWidget {
  const _FlightLayer({required this.legs, required this.onDone});

  final List<_Leg> legs;
  final VoidCallback onDone;

  @override
  State<_FlightLayer> createState() => _FlightLayerState();
}

class _FlightLayerState extends State<_FlightLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.standard,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, _) => Stack(
          children: [
            for (final leg in widget.legs)
              Positioned.fromRect(
                rect: leg.path.transform(_curve.value)!,
                child: leg.child,
              ),
          ],
        ),
      ),
    );
  }
}
