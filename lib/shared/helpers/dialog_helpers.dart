import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../widgets/ds_button.dart';
import '../widgets/ds_dialog.dart';
import '../widgets/ds_field.dart';
import '../widgets/ds_text_button.dart';

/// Helper per i dialog comuni dell'applicazione.
///
/// Ogni dialogo è un [DsDialog] aperto con [showDsDialog]. Convenzione
/// bottoni: due pill di pari larghezza ([DsDialog.twoActions]). Prima erano
/// due link testuali di peso identico, e per giunta "Annulla" era colorato
/// d'accento — cioè l'azione accentata era quella che non fa nulla.
///
/// La conferma distruttiva è rossa e non arancione: stessa forma e stesso
/// peso della primaria, ma un "Elimina" arancione accanto a un "Annulla"
/// grigio farebbe sembrare la cancellazione la strada consigliata.
class DialogHelpers {
  DialogHelpers._();

  /// Mostra un dialog di conferma eliminazione.
  ///
  /// [warningText] aggiunge una riga di avviso rossa sotto il messaggio principale
  /// (es. "questo bagaglio verrà rimosso da tutti i viaggi").
  ///
  /// Ritorna `true` se l'utente conferma, `false` altrimenti.
  static Future<bool> showDeleteConfirmation({
    required BuildContext context,
    required String itemType,
    required String itemName,
    String? customMessage,
    String? customTitle,
    String? warningText,
  }) async {
    final confirmed = await showDsDialog<bool>(
      context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return DsDialog(
          title: customTitle ?? 'dialogs.delete_title'.tr(args: [itemType]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customMessage ?? 'dialogs.delete_message'.tr(args: [itemName]),
              ),
              if (warningText != null) ...[
                SizedBox(height: dialogContext.spacingSm),
                Text(
                  warningText,
                  style: Theme.of(
                    dialogContext,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            DsDialog.twoActions(
              cancelLabel: 'dialogs.cancel'.tr(),
              onCancel: () => Navigator.pop(dialogContext, false),
              confirmLabel: 'dialogs.delete_confirm'.tr(),
              onConfirm: () => Navigator.pop(dialogContext, true),
              isDestructive: true,
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  /// Mostra un dialog generico di conferma.
  ///
  /// [isDestructive] usa il DsButton destruttivo per il bottone di conferma.
  /// Altrimenti usa DsButton primary.
  ///
  /// Ritorna `true` se l'utente conferma, `false` altrimenti.
  static Future<bool> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
  }) async {
    final confirmed = await showDsDialog<bool>(
      context,
      builder: (dialogContext) => DsDialog(
        title: title,
        message: message,
        actions: [
          DsDialog.twoActions(
            cancelLabel: cancelLabel ?? 'common.cancel'.tr(),
            onCancel: () => Navigator.pop(dialogContext, false),
            confirmLabel: confirmLabel ?? 'common.confirm'.tr(),
            onConfirm: () => Navigator.pop(dialogContext, true),
            isDestructive: isDestructive,
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  /// Conferma con **tre** uscite invece di due: annulla, un'azione secondaria
  /// e una primaria.
  ///
  /// Serve dove "sì/no" non basta a descrivere le scelte reali — il logout con
  /// modifiche non sincronizzate ne è l'esempio: uscire subito e uscire dopo
  /// aver sincronizzato sono due cose diverse, e nessuna delle due è "annulla".
  ///
  /// Ritorna `null` se l'utente annulla o chiude il dialog.
  static Future<T?> showChoice<T>({
    required BuildContext context,
    required String title,
    required String message,
    required String secondaryLabel,
    required T secondaryValue,
    required String primaryLabel,
    required T primaryValue,
    String? cancelLabel,
  }) {
    return showDsDialog<T>(
      context,
      builder: (dialogContext) => DsDialog(
        title: title,
        message: message,
        actions: [
          // Tre scelte impilate e non affiancate: tre pill su una riga
          // starebbero strette e le etichette andrebbero troncate proprio
          // dove servono per capire la differenza fra le due uscite.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DsButton(
                label: primaryLabel,
                expand: true,
                onPressed: () => Navigator.pop(dialogContext, primaryValue),
              ),
              SizedBox(height: dialogContext.spacingSm),
              DsButton(
                label: secondaryLabel,
                variant: DsButtonVariant.secondary,
                expand: true,
                onPressed: () => Navigator.pop(dialogContext, secondaryValue),
              ),
              SizedBox(height: dialogContext.spacingSm),
              DsButton(
                label: cancelLabel ?? 'common.cancel'.tr(),
                variant: DsButtonVariant.secondary,
                expand: true,
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Conferma distruttiva protetta dalla digitazione esatta di [requiredText]
  /// (pattern GitHub/Stripe: difficile da fare per sbaglio).
  ///
  /// Il bottone di conferma resta **visibile ma disabilitato** finché il testo
  /// non combacia: è la digitazione a fare da attrito, non un bottone
  /// nascosto.
  ///
  /// Ritorna `true` solo se l'utente ha digitato correttamente e confermato.
  static Future<bool> showProtectedDeleteConfirmation({
    required BuildContext context,
    required String title,
    required String warning,
    required String prompt,
    required String requiredText,
    required String confirmLabel,
  }) async {
    final confirmed = await showDsDialog<bool>(
      context,
      builder: (dialogContext) => _ProtectedDeleteDialog(
        title: title,
        warning: warning,
        prompt: prompt,
        requiredText: requiredText,
        confirmLabel: confirmLabel,
      ),
    );
    return confirmed ?? false;
  }

  /// Mostra un dialog informativo con un solo bottone "OK".
  ///
  /// [icon] opzionale viene mostrata sopra il titolo.
  /// [details] aggiunge bullet point rossi sotto il messaggio principale
  /// (es. conteggio oggetti quando non si può eliminare una casa).
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String? okLabel,
    IconData? icon,
    Color? iconColor,
    List<String>? details,
  }) async {
    await showDsDialog<void>(
      context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return DsDialog(
          title: title,
          icon: icon,
          iconColor:
              iconColor ?? theme.extension<AppColorsExtension>()!.warning,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (details != null && details.isNotEmpty) ...[
                SizedBox(height: dialogContext.spacingSm),
                for (final detail in details)
                  Padding(
                    padding: EdgeInsets.only(top: dialogContext.spacingXs),
                    child: Text(
                      '• $detail',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ],
          ),
          actions: [
            DsTextButton(
              onPressed: () => Navigator.pop(dialogContext),
              label: okLabel ?? 'common.ok'.tr(),
            ),
          ],
        );
      },
    );
  }
}

/// Corpo di [DialogHelpers.showProtectedDeleteConfirmation].
///
/// È uno [StatefulWidget] e non un builder inline perché ha un
/// [TextEditingController] da creare e distruggere: dentro il builder del
/// dialogo il controller verrebbe ricostruito a ogni rebuild e mai disposto.
class _ProtectedDeleteDialog extends StatefulWidget {
  final String title;
  final String warning;
  final String prompt;
  final String requiredText;
  final String confirmLabel;

  const _ProtectedDeleteDialog({
    required this.title,
    required this.warning,
    required this.prompt,
    required this.requiredText,
    required this.confirmLabel,
  });

  @override
  State<_ProtectedDeleteDialog> createState() => _ProtectedDeleteDialogState();
}

class _ProtectedDeleteDialogState extends State<_ProtectedDeleteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches =>
      _controller.text.trim().toLowerCase() ==
      widget.requiredText.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DsDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.warning),
          SizedBox(height: context.spacingMd),
          Text(widget.prompt, style: theme.textTheme.bodySmall),
          SizedBox(height: context.spacingSm),
          DsTextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            hintText: widget.requiredText,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        // Stesse pill delle altre conferme. Il bottone resta visibile ma
        // spento finché l'email non combacia: l'attrito lo fa la digitazione,
        // e uno spento senza accento lo dice già da sé.
        DsDialog.twoActions(
          cancelLabel: 'dialogs.cancel'.tr(),
          onCancel: () => Navigator.pop(context, false),
          confirmLabel: widget.confirmLabel,
          onConfirm: _matches ? () => Navigator.pop(context, true) : null,
          isDestructive: true,
        ),
      ],
    );
  }
}
