import 'package:flutter/material.dart';

/// Scaffold standard per le schermate principali (tab) dell'app.
///
/// Il body occupa **tutta** l'altezza disponibile, area della nav bar inclusa:
/// il contenuto scorre quindi dietro la pill flottante di `MainShell`, che è
/// l'effetto voluto (stesso pattern di `StickyCtaScaffold` per la CTA).
///
/// Prima questo scaffold avvolgeva il body in un `Padding` inferiore pari a
/// `context.navBarReservedHeight`. Sembrava innocuo, ma sotto `extendBody:
/// true` quel valore **non** è la sola gesture bar: Flutter gonfia
/// `MediaQuery.padding.bottom` fino all'altezza dell'intera
/// `bottomNavigationBar` (vedi `_BodyBuilder` in scaffold.dart, che fa
/// `max(padding.bottom, bottomWidgetsHeight)`). Il body veniva quindi
/// rimpicciolito esattamente dell'altezza della nav bar e il contenuto si
/// fermava al bordo superiore della pill — mai dietro di essa.
///
/// **Ogni schermata deve quindi sommare `context.navBarReservedHeight` al
/// padding inferiore della propria scrollable**, così l'ultimo elemento può
/// essere portato sopra la nav bar invece di restarci sotto per sempre.
class ShellTabScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;

  const ShellTabScaffold({super.key, this.appBar, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        // Il bottom è gestito da navBarReservedHeight (che include già la
        // gesture bar / home indicator) — non doppio-contiamo con SafeArea.
        bottom: false,
        // Se c'è un AppBar, lo status bar è già liberato da lui (la sua
        // altezza include quello spazio): SafeArea(top: true) aggiungerebbe
        // un secondo padding superiore identico sopra quello già riservato
        // dall'AppBar — lo stesso doppio conteggio del bottom, ma in cima.
        // Misurato su device: senza questo fix il primo elemento della lista
        // profilo partiva a 187dp invece di ~122dp attesi (AppBar + status
        // bar), un surplus che coincideva esattamente con lo status bar
        // stesso. Le schermate senza AppBar (Case, Viaggi) restano protette:
        // lì nessun altro widget libera lo status bar, quindi serve davvero.
        top: appBar == null,
        // Nessun `Padding` inferiore e nessun `MediaQuery.removePadding`: il
        // body arriva fino in fondo. Uno scrollable con `padding: null` si
        // riserva da sé `MediaQuery.padding.bottom` (già pari all'altezza
        // della nav bar, vedi sopra); quelli con padding esplicito devono
        // sommarci `context.navBarReservedHeight`. In entrambi i casi il
        // reserve resta uno solo.
        child: body,
      ),
    );
  }
}
