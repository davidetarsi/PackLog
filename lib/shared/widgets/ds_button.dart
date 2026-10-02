import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// Livello semantico di un [DsButton].
enum DsButtonVariant {
  /// Azione principale della schermata. Riempimento pieno.
  primary,

  /// Azione di contorno. Superficie con bordo e testo d'accento.
  secondary,

  /// Azione distruttiva (elimina, esci definitivamente). Riempimento rosso.
  destructive,
}

/// Bottone pill dell'app: **unica** implementazione di forma, colore e stati.
///
/// Vive qui e non nei temi Material (`filledButtonTheme` &c.) perché quei temi
/// governano forma e padding ma non la scala a tre livelli, che è la parte che
/// conta: usarli avrebbe lasciato due fonti di verità per la stessa decisione.
/// [UniversalActionBar] monta questo stesso widget, quindi la CTA sticky in
/// fondo alle schermate e i bottoni inline non possono divergere.
///
/// ## La scala
///
/// Una regola sola: **l'accento colorato è presente solo se il bottone si può
/// toccare.**
///
/// | Livello | Sfondo | Bordo | Testo |
/// |---|---|---|---|
/// | primary | `primary` | `primary` | `onPrimary` |
/// | destructive | `error` | `error` | `onError` |
/// | secondary | trasparente | `primary` | `primary` |
/// | disabilitato | `surface` | `outline` | `onSurface` al 38% |
///
/// Il testo chiaro sul riempimento arancione non è un'opzione: dà 2,33:1 nel
/// tema scuro, contro i 4,5:1 richiesti. Da qui `onPrimary` scuro.
class DsButton extends StatelessWidget {
  final String label;

  /// `null` disabilita il bottone e ne spegne l'accento.
  final VoidCallback? onPressed;

  /// Invocato al tocco mentre il bottone è spento.
  ///
  /// Un bottone disabilitato che non reagisce lascia l'utente a indovinare
  /// cosa manchi. Con questa callback resta spento — la scala continua a dire
  /// che non è pronto — ma il tocco può spiegare perché.
  final VoidCallback? onDisabledTap;

  final IconData? icon;
  final DsButtonVariant variant;

  /// Mostra uno spinner al posto dell'etichetta. Il bottone **resta del suo
  /// colore**: durante il salvataggio non è "spento", sta lavorando.
  final bool isLoading;

  /// Occupa tutta la larghezza disponibile.
  final bool expand;

  const DsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onDisabledTap,
    this.icon,
    this.variant = DsButtonVariant.primary,
    this.isLoading = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Toccabile e "spento" sono due cose diverse: vedi [isLoading].
    final canTap = onPressed != null && !isLoading;
    final looksDisabled = onPressed == null;

    final Color backgroundColor;
    final Color accentColor;
    final Color contentColor;

    if (looksDisabled) {
      // 38% è la convenzione Material per il disabilitato: volutamente sotto
      // le soglie di contrasto, perché "non toccabile" deve leggersi prima
      // ancora del testo.
      backgroundColor = colorScheme.surface;
      accentColor = colorScheme.outline;
      contentColor = colorScheme.onSurface.withValues(alpha: 0.38);
    } else {
      switch (variant) {
        case DsButtonVariant.destructive:
          backgroundColor = colorScheme.error;
          accentColor = colorScheme.error;
          contentColor = colorScheme.onError;
        case DsButtonVariant.secondary:
          // Sfondo trasparente e non `surface`: così il bottone prende il
          // colore di ciò che gli sta sotto. Dentro un dialog, il cui fondo è
          // più chiaro della surface, una superficie opaca disegnava un
          // rettangolo scuro visibile attorno all'etichetta.
          //
          // Sicuro perché nessun call site monta un secondary sopra contenuto
          // scorrevole: le CTA sticky sono tutte primary o destructive.
          backgroundColor = Colors.transparent;
          accentColor = colorScheme.primary;
          contentColor = colorScheme.primary;
        case DsButtonVariant.primary:
          backgroundColor = colorScheme.primary;
          accentColor = colorScheme.primary;
          contentColor = colorScheme.onPrimary;
      }
    }

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
      // elevation: 0 elimina il layer di ombra nel compositing: quando il
      // bottone fluttua sopra liste scorrevoli, ogni frame non richiede un
      // shadow pass separato sull'engine Impeller.
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
        // Spento non vuol dire inerte: se il chiamante ha qualcosa da dire sul
        // perché, il tocco lo raccoglie comunque. Durante il caricamento no,
        // lì il bottone sta già lavorando.
        onTap: canTap ? onPressed : (isLoading ? null : onDisabledTap),
        child: Container(
          width: expand ? double.infinity : null,
          height: context.responsive(56),
          padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
          decoration: BoxDecoration(
            // Nessun colore qui: lo sfondo è già gestito da Material.
            // Aggiungere color in BoxDecoration causerebbe un layer di pittura
            // aggiuntivo sovrapposto a quello di Material.
            borderRadius: BorderRadius.circular(AppConstants.pillBorderRadius),
            border: Border.all(color: accentColor, width: 2),
          ),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: context.responsive(24),
                    height: context.responsive(24),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      // Segue il testo, non l'accento: su un riempimento
                      // primary uno spinner primary sarebbe invisibile.
                      color: contentColor,
                      // strokeAlignCenter evita artefatti di anti-aliasing
                      // sul bordo esterno durante l'animazione di rotazione.
                      strokeAlign: CircularProgressIndicator.strokeAlignCenter,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: contentColor, size: context.iconSizeMd),
                      SizedBox(width: context.spacingSm),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: contentColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
