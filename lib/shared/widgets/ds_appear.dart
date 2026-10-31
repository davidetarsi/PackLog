import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Comparsa morbida di un elemento nuovo: dissolvenza e apertura in altezza,
/// con la stessa curva, in [AppMotion.slow].
///
/// Si anima una sola volta, alla prima costruzione: un nuovo build con la
/// stessa chiave non la fa ripartire. Con le animazioni di sistema disattivate
/// (`MediaQuery.disableAnimationsOf`) l'elemento compare subito.
class DsAppear extends StatefulWidget {
  final Widget child;

  const DsAppear({super.key, required this.child});

  @override
  State<DsAppear> createState() => _DsAppearState();
}

class _DsAppearState extends State<DsAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.slow);
    _curved = CurvedAnimation(parent: _controller, curve: AppMotion.emphasized);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Animazioni disattivate: si salta alla fine. Il controller non riparte
    // mai da capo, quindi un cambio di MediaQuery non rifà la comparsa.
    if (MediaQuery.disableAnimationsOf(context) && !_controller.isCompleted) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _curved,
      axisAlignment: -1,
      child: FadeTransition(opacity: _curved, child: widget.child),
    );
  }
}
