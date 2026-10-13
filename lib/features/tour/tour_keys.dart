import 'package:flutter/widgets.dart';

final tourKeys = _TourKeys();

class _TourKeys {
  final housesTab = GlobalKey();
  final tripsTab = GlobalKey();
  final profileTab = GlobalKey();
  final infoCardTarget = GlobalKey();
  final houseFab = GlobalKey();

  /// Riga "Nuova casa" in fondo alla lista case. Target di
  /// [OnboardingStep.houseTooltip].
  final newHouseRow = GlobalKey();

  /// Riga filtri categoria in cima a [HouseDetailScreen]. Target di
  /// [OnboardingStep.moveItemsTooltip]: sempre presente (anche a lista
  /// vuota), a differenza di evidenziare una card item specifica.
  final houseItemsAnchor = GlobalKey();
}
