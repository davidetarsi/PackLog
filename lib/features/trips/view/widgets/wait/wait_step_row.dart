import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';

enum WaitStepState { done, current, pending }

/// Un passo dell'attesa: puntino fermo e scuro se in attesa o chiaro, che
/// lampeggia se in corso, spunta se chiuso. Da chiuso, sotto compare in
/// dissolvenza la riga col dato vero ([result]), se c'è.
class WaitStepRow extends StatelessWidget {
  const WaitStepRow({
    super.key,
    required this.label,
    required this.state,
    this.result,
  });

  final String label;
  final WaitStepState state;
  final String? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pending = state == WaitStepState.pending;
    final line = state == WaitStepState.done ? result : null;

    final Widget marker = switch (state) {
      WaitStepState.done => Icon(
        Icons.check,
        key: const Key('ai_wait_check'),
        size: context.iconSizeSm,
        color: colorScheme.onSurface,
      ),
      WaitStepState.current => _Blinking(
        child: _Dot(color: colorScheme.onSurface),
      ),
      WaitStepState.pending => _Dot(color: colorScheme.outlineVariant),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: context.iconSizeMd,
          child: Center(child: marker),
        ),
        SizedBox(width: context.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.spacingXxs),
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: pending
                        ? colorScheme.outline
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              AnimatedSize(
                duration: AppMotion.medium,
                curve: AppMotion.standard,
                alignment: Alignment.topLeft,
                child: AnimatedOpacity(
                  key: const Key('ai_wait_result'),
                  duration: AppMotion.slow,
                  curve: AppMotion.emphasized,
                  opacity: line == null ? 0 : 1,
                  child: line == null
                      ? const SizedBox(width: double.infinity)
                      : Text(
                          line,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.spacingSm,
      height: context.spacingSm,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Fa lampeggiare [child] finché resta a schermo.
class _Blinking extends StatefulWidget {
  const _Blinking({required this.child});

  final Widget child;

  @override
  State<_Blinking> createState() => _BlinkingState();
}

class _BlinkingState extends State<_Blinking>
    with SingleTickerProviderStateMixin {
  static const Duration _period = Duration(milliseconds: 700);
  static const double _minOpacity = 0.2;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      key: const Key('ai_wait_blinking_dot'),
      opacity: Tween<double>(begin: 1, end: _minOpacity).animate(_controller),
      child: widget.child,
    );
  }
}
