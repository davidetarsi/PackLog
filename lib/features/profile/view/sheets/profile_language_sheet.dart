import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/ds_picker_sheet.dart';

/// Foglio dal basso per scegliere la lingua dell'app.
///
/// Le bandiere sono il leading di ogni riga: Regno Unito per l'inglese, non
/// Stati Uniti. Se la lingua scelta è diversa da quella attuale la cambia.
Future<void> showProfileLanguageSheet(BuildContext context) async {
  final picked = await DsPickerSheet.show<Locale>(
    context: context,
    title: 'settings.language'.tr(),
    items: const [Locale('it', 'IT'), Locale('en', 'US')],
    getLabel: (locale) => _languageName(locale),
    getLeading: (locale) =>
        Text(_flag(locale), style: Theme.of(context).textTheme.titleLarge),
    selected: context.locale,
  );

  // Il cambio lingua avviene dopo la chiusura del foglio: serve il context
  // della schermata, che può essere smontato nel frattempo.
  if (picked == null || !context.mounted) return;
  if (picked == context.locale) return;
  await context.setLocale(picked);
}

// I nomi delle lingue restano nella lingua stessa, come da convenzione.
String _languageName(Locale locale) =>
    locale.languageCode == 'it' ? 'Italiano' : 'English';

String _flag(Locale locale) => locale.languageCode == 'it' ? '🇮🇹' : '🇬🇧';
