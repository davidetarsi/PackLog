import 'package:flutter/widgets.dart';

final tourKeys = _TourKeys();

class _TourKeys {
  final housesTab = GlobalKey();
  final tripsTab = GlobalKey();
  final infoCardTarget = GlobalKey();

  /// Voce "Crea" al centro della barra. Target di
  /// [OnboardingStep.createTripTooltip].
  final primaryAction = GlobalKey();

  /// Riga "Nuova casa" (in fondo alla lista, o nello stato vuoto). Target di
  /// [OnboardingStep.houseTooltip].
  final newHouseRow = GlobalKey();

  /// Riga filtri categoria in cima a [HouseDetailScreen]. Target di
  /// [OnboardingStep.moveItemsTooltip]: sempre presente (anche a lista
  /// vuota), a differenza di evidenziare una card item specifica.
  final houseItemsAnchor = GlobalKey();
}
