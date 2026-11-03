import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';

/// Lo spazio in fondo alla lista con un posto aperto: alto come la vista, per
/// portare in cima anche l'ultimo gruppo.
///
/// All'apertura è intero subito. Alla chiusura resta intero mentre la pagina
/// scorre, con [AppMotion.medium], fino a dove arriverebbe senza lo spazio;
/// solo dopo sparisce, e il suo sparire non sposta più nulla. Con le
/// animazioni di sistema spente il passaggio è immediato.
class SlotEndSpacer extends StatefulWidget {
  const SlotEndSpacer(this.open, this.height, {super.key});

  final bool open;
  final double height;

  /// Quanto aspettare dopo la chiusura perché la pagina abbia finito di
  /// scorrere (zero con le animazioni spente).
  static Duration settle(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : AppMotion.medium + const Duration(milliseconds: 32);

  @override
  State<SlotEndSpacer> createState() => _SlotEndSpacerState();
}

class _SlotEndSpacerState extends State<SlotEndSpacer> {
  /// Il posto si è chiuso ma la pagina sta ancora scorrendo.
  bool _scrolling = false;

  @override
  void didUpdateWidget(SlotEndSpacer old) {
    super.didUpdateWidget(old);
    if (old.open && !widget.open) {
      _scrolling = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBack());
    }
  }

  Future<void> _scrollBack() async {
    if (!mounted) return;
    final position = Scrollable.maybeOf(context)?.position;
    if (position != null && position.hasPixels) {
      final target = position.pixels.clamp(
        position.minScrollExtent,
        (position.maxScrollExtent - widget.height).clamp(
          position.minScrollExtent,
          double.infinity,
        ),
      );
      if (target != position.pixels) {
        if (MediaQuery.disableAnimationsOf(context)) {
          position.jumpTo(target);
        } else {
          await position.animateTo(
            target,
            duration: AppMotion.medium,
            curve: AppMotion.standard,
          );
        }
      }
    }
    if (mounted) setState(() => _scrolling = false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('slot_end_spacer'),
      height: widget.open || _scrolling ? widget.height : 0,
    );
  }
}
