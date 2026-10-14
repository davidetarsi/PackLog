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

  /// Etichetta del primo gruppo della lista in [HouseDetailScreen] (o lo
  /// stato vuoto, se la casa non ha oggetti). Target di
  /// [OnboardingStep.moveItemsTooltip].
  final houseItemsAnchor = GlobalKey();
}
