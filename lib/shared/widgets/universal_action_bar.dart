import 'package:flutter/material.dart';
import 'package:pack_log/shared/widgets/tri_slot_bar.dart';
import 'ds_button.dart';

/// Action bar universale con bottone primario centrato perfettamente.
///
/// Fornisce un layout consistente per le azioni bottom delle schermate:
/// - Bottone primario (center) sempre perfettamente centrato
/// - Azioni laterali opzionali (left/right) che non influenzano la centratura
/// - Elevazione e stile pill consistenti
///
/// **Pattern Critico di Centratura:**
/// Usa `Expanded` + `Align` per i slot laterali, garantendo che il
/// bottone centrale rimanga perfettamente centrato anche quando
/// left/right sono null.
///
/// Esempio:
/// ```dart
/// UniversalActionBar(
///   primaryLabel: 'Continua',
///   onPrimaryPressed: () => _next(),
///   leftAction: CircularActionButton(icon: Icons.delete, ...),
///   rightAction: CircularActionButton(icon: Icons.edit, ...),
/// )
/// ```
class UniversalActionBar extends StatelessWidget {
  /// Label del bottone primario centrale
  final String primaryLabel;

  /// Callback per il bottone primario
  final VoidCallback? onPrimaryPressed;

  /// Icona opzionale per il bottone primario
  final IconData? primaryIcon;

  /// Widget azione sinistra (es: CircularActionButton per delete)
  final Widget? leftAction;

  /// Widget azione destra (es: CircularActionButton per add/edit)
  final Widget? rightAction;

  /// Mostra loading indicator nel bottone primario
  final bool isLoading;

  /// Usa bordo outline (grigio) invece di primary. Per azioni secondarie/distruttive
  /// che non devono richiamare l'attenzione come un'azione primaria.
  final bool isSecondary;

  /// Usa bordo e testo rosso (colorScheme.error). Per azioni irreversibili
  /// come l'eliminazione dell'account.
  final bool isDestructive;

  /// Key applicata al bottone primario. Serve ai test per toccare la pill e
  /// non la barra che la contiene.
  final Key? primaryButtonKey;

  const UniversalActionBar({
    super.key,
    required this.primaryLabel,
    this.onPrimaryPressed,
    this.primaryIcon,
    this.leftAction,
    this.rightAction,
    this.isLoading = false,
    this.isSecondary = false,
    this.isDestructive = false,
    this.primaryButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    final isSingleAction = leftAction == null && rightAction == null;

    // Il bottone è [DsButton], lo stesso usato inline nelle schermate: forma,
    // colori e stati vivono in un punto solo, quindi la CTA sticky e i bottoni
    // dentro le pagine non possono divergere.
    final primaryButton = DsButton(
      key: primaryButtonKey,
      label: primaryLabel,
      icon: primaryIcon,
      onPressed: onPrimaryPressed,
      isLoading: isLoading,
      expand: isSingleAction,
      variant: isDestructive
          ? DsButtonVariant.destructive
          : isSecondary
          ? DsButtonVariant.secondary
          : DsButtonVariant.primary,
    );

    return TriSlotBar(
      horizontalPadding: 0,
      left: leftAction,
      right: rightAction,
      center: primaryButton,
    );
  }
}
