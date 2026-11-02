import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';

/// La bolla che scoppia: con [popping] il figlio si ingrandisce appena e si
/// dissolve (con [AppMotion.medium] e [AppMotion.standard]), poi chiama
/// [onDone] una volta sola.
///
/// Con le animazioni di sistema disattivate chiama subito [onDone] (dopo il
/// frame, mai durante la costruzione). Non sa niente di cosa contiene.
class SlotPop extends StatefulWidget {
  const SlotPop({
    super.key,
    required this.child,
    required this.popping,
    this.onDone,
  });

  final Widget child;
  final bool popping;
  final VoidCallback? onDone;

  @override
  State<SlotPop> createState() => _SlotPopState();
}

/// Di quanto si ingrandisce prima di dissolversi.
const _burstScale = 1.08;

class _SlotPopState extends State<SlotPop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
  )..addStatusListener(_onStatus);

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.standard,
  );

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onDone?.call();
  }

  @override
  void initState() {
    super.initState();
    if (widget.popping) _pop();
  }

  @override
  void didUpdateWidget(SlotPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.popping && !oldWidget.popping) _pop();
  }

  void _pop() {
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDone?.call();
      });
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: ReverseAnimation(_curve),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: _burstScale).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
