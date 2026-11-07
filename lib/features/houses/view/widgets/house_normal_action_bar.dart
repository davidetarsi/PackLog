import 'package:flutter/material.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import '../../../../shared/widgets/circular_action_button.dart';
import '../../../items/widgets/rapid_fire_input.dart';

/// Altezza degli elementi della barra in basso (campo rapid fire e bottone AI).
const kHouseBottomBarHeight = 50.0;

/// Bottom action bar in modalità normale: campo rapid-fire (sinistra) e
/// scansione AI (destra). "⋮" e ricerca stanno nell'intestazione.
class HouseNormalActionBar extends StatelessWidget {
  final String houseId;
  final VoidCallback onAiScan;
  final bool autofocusRapidFire;
  final bool isExpanded;
  final String? currentSpaceId;
  final void Function(bool) onExpandedChanged;
  final FocusNode focusNode;
  final ValueChanged<String> onTextChanged;

  const HouseNormalActionBar({
    super.key,
    required this.houseId,
    required this.onAiScan,
    required this.autofocusRapidFire,
    required this.isExpanded,
    required this.currentSpaceId,
    required this.onExpandedChanged,
    required this.focusNode,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final elementHeight = context.responsive(kHouseBottomBarHeight);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: RapidFireInput(
              houseId: houseId,
              autofocus: autofocusRapidFire,
              currentSpaceId: currentSpaceId,
              height: elementHeight,
              onExpandedChanged: onExpandedChanged,
              onTextChanged: onTextChanged,
              focusNode: focusNode,
            ),
          ),
          // Mentre si scrive il campo prende tutta la riga.
          if (!isExpanded) ...[
            SizedBox(width: context.spacingSm),
            CircularActionButton(
              icon: Icons.auto_awesome,
              // L'unico arancio della schermata: la scansione AI è la strada
              // che vogliamo far prendere per aggiungere oggetti.
              color: Theme.of(context).colorScheme.primary,
              showBorder: true,
              onPressed: onAiScan,
            ),
          ],
        ],
      ),
    );
  }
}
