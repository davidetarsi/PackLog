import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Bottone d'azione della shell, staccato dalla barra dei luoghi.
///
/// All'avvio e a ogni cambio di [label] si allarga mostrando l'etichetta per
/// [labelDuration], poi torna tondo con la sola icona. Con `enabled: false`
/// diventa tonale (non arancio) ma **risponde comunque al tocco**: chi lo usa
/// spiega perché l'azione non è disponibile.
class PrimaryActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final Duration labelDuration;

  const PrimaryActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.labelDuration = const Duration(seconds: 2),
  });

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton> {
  bool _showLabel = true;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    _scheduleCollapse();
  }

  @override
  void didUpdateWidget(PrimaryActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label) {
      setState(() => _showLabel = true);
      _scheduleCollapse();
    }
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(widget.labelDuration, () {
      if (mounted) setState(() => _showLabel = false);
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = widget.enabled
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final foreground = widget.enabled
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;
    final size = context.responsive(56);

    return Semantics(
      button: true,
      label: widget.label,
      // L'etichetta è già nel nodo semantico: senza questo il Text la fa
      // leggere una seconda volta.
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        elevation: widget.enabled ? 3 : 0,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: widget.onPressed,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: Container(
              height: size,
              // Con caratteri grandi l'etichetta non deve schiacciare la barra
              // dei luoghi accanto: il bottone espanso ha un tetto di larghezza.
              constraints: BoxConstraints(
                minWidth: size,
                maxWidth: math.max(
                  size,
                  MediaQuery.sizeOf(context).width * 0.45,
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: _showLabel ? context.spacingMd : 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    color: foreground,
                    size: context.iconSizeMd,
                  ),
                  if (_showLabel) ...[
                    SizedBox(width: context.spacingSm),
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
