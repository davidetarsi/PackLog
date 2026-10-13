import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Peso visivo del bottone d'azione quando è attivo.
enum PrimaryActionStyle {
  /// Arancio pieno: il massimo richiamo.
  filled,

  /// Arancio chiaro (`primaryContainer`): azione principale ma più leggera.
  tonal,

  /// Sfondo della barra con bordo e contenuto arancio.
  outlined,
}

/// Bottone d'azione della shell, staccato dalla barra dei luoghi.
///
/// Stessa struttura delle voci della barra (icona sopra, etichetta breve
/// sotto) così si legge come "l'azione di questa tab". [semanticLabel] è la
/// frase completa per TalkBack ("Aggiungi oggetti"), [label] la parola breve
/// a schermo ("Oggetto").
///
/// Con `enabled: false` usa i valori di disabilitato di Material 3 (contenuto
/// al 38%, superficie al 12%) ma **risponde comunque al tocco**: chi lo usa
/// spiega perché l'azione non è disponibile.
class PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onPressed;
  final bool enabled;
  final PrimaryActionStyle style;

  const PrimaryActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.enabled = true,
    this.style = PrimaryActionStyle.outlined,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (Color background, Color foreground, BorderSide border) = !enabled
        ? (
            colorScheme.onSurface.withValues(alpha: 0.12),
            colorScheme.onSurface.withValues(alpha: 0.38),
            BorderSide.none,
          )
        : switch (style) {
            PrimaryActionStyle.filled => (
              colorScheme.primary,
              colorScheme.onPrimary,
              BorderSide.none,
            ),
            PrimaryActionStyle.tonal => (
              colorScheme.primaryContainer,
              colorScheme.onPrimaryContainer,
              BorderSide.none,
            ),
            PrimaryActionStyle.outlined => (
              colorScheme.surfaceContainer,
              colorScheme.primary,
              BorderSide(color: colorScheme.primary, width: 1.5),
            ),
          };

    final shape = RoundedRectangleBorder(
      borderRadius: context.responsiveBorderRadius(
        AppConstants.pillBorderRadius,
      ),
      side: border,
    );
    final height = context.responsive(56);

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      // La parola breve a schermo non deve essere letta in aggiunta.
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: shape,
        elevation: enabled && style == PrimaryActionStyle.filled ? 3 : 0,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: context.responsive(64),
              maxWidth: context.responsive(96),
              minHeight: height,
              maxHeight: height,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingSm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: foreground, size: context.responsive(22)),
                  SizedBox(height: context.spacingXs / 4),
                  // L'altezza è quella della barra: con caratteri molto grandi
                  // l'etichetta smetterebbe di starci sotto l'icona.
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
