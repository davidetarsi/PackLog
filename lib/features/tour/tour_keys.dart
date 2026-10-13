import 'package:flutter/widgets.dart';

final tourKeys = _TourKeys();

class _TourKeys {
  final housesTab = GlobalKey();
  final tripsTab = GlobalKey();
  final infoCardTarget = GlobalKey();

  /// Bottone d'azione della shell (Aggiungi oggetti / Nuovo viaggio).
  final primaryAction = GlobalKey();

  /// Riga "Nuova casa" in fondo alla lista case. Target di
  /// [OnboardingStep.houseTooltip].
  final newHouseRow = GlobalKey();

  /// Riga filtri categoria in cima a [HouseDetailScreen]. Target di
  /// [OnboardingStep.moveItemsTooltip]: sempre presente (anche a lista
  /// vuota), a differenza di evidenziare una card item specifica.
  final houseItemsAnchor = GlobalKey();
}
