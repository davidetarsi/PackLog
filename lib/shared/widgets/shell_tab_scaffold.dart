import 'package:flutter/material.dart';
import '../theme/nav_bar_spacing.dart';

/// Scaffold standard per le schermate principali (tab) dell'app.
///
/// Gestisce SafeArea e, opzionalmente, riserva lo spazio occupato dalla
/// floating navigation bar in basso così che il contenuto della pagina
/// non finisca sotto di essa.
///
/// Usa [reserveBottomNavSpace] = true (default) quando il body non gestisce
/// autonomamente il padding inferiore. Impostalo a false solo se il body
/// contiene già un layout che applica [navBarReservedHeight] (es. una lista
/// con padding bottom esplicito).
class ShellTabScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;

  /// Se true (default), aggiunge un padding inferiore pari a [navBarReservedHeight]
  /// attorno al body così il contenuto non scorre sotto la nav bar floating.
  final bool reserveBottomNavSpace;

  const ShellTabScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.reserveBottomNavSpace = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        // Il bottom è gestito da navBarReservedHeight (che include già la
        // gesture bar / home indicator) — non doppio-contiamo con SafeArea.
        bottom: false,
        child: reserveBottomNavSpace
            // `MediaQuery.removePadding(removeBottom: true)` è **critico**: senza,
            // uno scrollable con `padding: null` (ListView, CustomScrollView…)
            // dentro `body` ri-applica automaticamente `MediaQuery.padding.bottom`
            // come proprio padding inferiore. Sommato al [Padding] esplicito qui
            // sotto (anch'esso = navBarReservedHeight) si otterrebbe un reserve
            // DOPPIO in fondo alla pagina — un grande spazio vuoto sopra la nav
            // bar. Rimuovendo il bottom dal MediaQuery per i discendenti, il
            // reserve resta uno solo (quello del [Padding]).
            ? MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: context.navBarReservedHeight,
                  ),
                  child: body,
                ),
              )
            : body,
      ),
    );
  }
}
