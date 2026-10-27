import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/core_analytics_service.dart';
import '../../features/ai_input/helpers/start_ai_scan.dart';
import '../../features/houses/view/add_edit_house_screen.dart';
import '../../features/profile/providers/gpt_usage_provider.dart';
import '../../features/promo/model/promo_redeem_result.dart';
import '../../features/promo/providers/promo_code_provider.dart';
import '../../features/promo/view/promo_code_sheet.dart';
import '../../features/tour/tour_keys.dart';
import '../helpers/snack_bar_helper.dart';
import '../theme/app_spacing.dart';
import 'create_sheet.dart';
import 'ds_floating_bar.dart';

/// Shell principale: barra flottante Case · Crea · Viaggi.
///
/// "Crea" è sempre lo stesso in ogni tab e apre il foglio Crea, dove la
/// scansione AI è la scelta principale. La tab corrente decide solo l'ordine
/// delle voci sotto (vedi [showCreateSheet]).
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  static const _housesBranch = 0;
  static const _tripsBranch = 1;

  void _goBranch(int index) =>
      navigationShell.goBranch(index, initialLocation: false);

  Future<void> _onCreate(
    BuildContext context,
    WidgetRef ref, {
    required bool fromTrips,
  }) async {
    final analytics = ref.read(coreAnalyticsServiceProvider);
    final tab = fromTrips ? 'trips' : 'houses';
    analytics.trackCreateTapped(tab: tab);

    final choice = await showCreateSheet(context);
    if (choice == null || !context.mounted) return;

    switch (choice.action) {
      case CreateAction.aiScan:
        analytics.trackCreateSheetChoice(choice: 'ai_scan', tab: tab);
        await startAiScan(context, ref, choice.houseId!);
      case CreateAction.manualItems:
        analytics.trackCreateSheetChoice(choice: 'manual_items', tab: tab);
        // L'inserimento a mano passa dal rapid fire della casa, già attivo.
        context.push('/houses/${choice.houseId}?add=manual');
      case CreateAction.newHouse:
        analytics.trackCreateSheetChoice(choice: 'new_house', tab: tab);
        await showAddEditHouseSheet(context);
      case CreateAction.newTrip:
        analytics.trackCreateSheetChoice(choice: 'new_trip', tab: tab);
        context.push('/new-trip');
      case CreateAction.aiSuitcase:
        analytics.trackCreateSheetChoice(choice: 'ai_suitcase', tab: tab);
        context.push('/new-trip?ai=1');
    }
  }

  /// L'esito del codice promo scritto al login, attivato dopo l'accesso:
  /// la shell è la prima schermata con una snackbar a disposizione. Si legge
  /// con `watch` e non con `listen` perché l'esito può arrivare prima che la
  /// shell esista (per esempio durante l'onboarding).
  void _showPendingPromoOutcome(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(pendingPromoOutcomeProvider);
    if (outcome == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ref.read(pendingPromoOutcomeProvider.notifier).clear();
      switch (outcome) {
        case PromoRedeemed():
          ref.invalidate(gptUsageProvider);
          AppSnackBar.showSuccess(context, promoRedeemedMessage(outcome));
        case PromoRejected(:final reason):
          AppSnackBar.showError(context, reason.messageKey.tr());
        case PromoFailed():
          AppSnackBar.showError(context, 'promo.error_generic'.tr());
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onHouses = navigationShell.currentIndex == _housesBranch;
    _showPendingPromoOutcome(context, ref);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Anchor invisibile per gli step info-card del tour (nessun spotlight)
          Center(
            child: SizedBox(key: tourKeys.infoCardTarget, width: 1, height: 1),
          ),
          navigationShell,
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.spacingMd,
            0,
            context.spacingMd,
            context.spacingMd,
          ),
          child: DsFloatingBar(
            children: [
              DsBarItem(
                key: const Key('nav_houses'),
                anchorKey: tourKeys.housesTab,
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'navigation.houses'.tr(),
                isSelected: onHouses,
                onTap: () => _goBranch(_housesBranch),
              ),
              DsBarItem(
                key: const Key('nav_create'),
                anchorKey: tourKeys.primaryAction,
                icon: Icons.add_circle_outline,
                label: 'common.create'.tr(),
                accent: true,
                onTap: () => _onCreate(context, ref, fromTrips: !onHouses),
              ),
              DsBarItem(
                key: const Key('nav_trips'),
                anchorKey: tourKeys.tripsTab,
                icon: Icons.luggage_outlined,
                selectedIcon: Icons.luggage,
                label: 'navigation.trips'.tr(),
                isSelected: !onHouses,
                onTap: () => _goBranch(_tripsBranch),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
