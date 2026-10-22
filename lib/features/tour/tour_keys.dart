import 'package:flutter/widgets.dart';

final tourKeys = _TourKeys();

class _TourKeys {
  final housesTab = GlobalKey();
  final tripsTab = GlobalKey();
  final infoCardTarget = GlobalKey();

  /// Voce "Crea" al centro della barra. Target di
  /// [OnboardingStep.createTripTooltip].
  final primaryAction = GlobalKey();

  /// Nome della casa nell'AppBar di [HouseDetailScreen]. Target di
  /// [OnboardingStep.houseDetailTooltip].
  final houseTitle = GlobalKey();
}
