import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'consent_service.dart';

part 'consent_provider.g.dart';

/// Istanza condivisa di [ConsentService].
///
/// `keepAlive` perché lo stato del consenso è globale e viene interrogato dal
/// gate di `AppAnalyticsService` a ogni evento: ricrearlo significherebbe
/// perdere l'idratazione in memoria e ricadere nel fail-closed.
///
/// L'istanza è restituita **subito**, non idratata: `load()` viene invocata da
/// `bootstrap.dart` prima che l'UI sia interattiva. Finché non completa,
/// `hasConsent` resta `false` e gli eventi vengono scartati.
@Riverpod(keepAlive: true)
ConsentService consentService(Ref ref) => ConsentService();
