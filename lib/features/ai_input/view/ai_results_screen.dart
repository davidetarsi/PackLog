import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/constants/house_icons.dart';
import '../../../shared/helpers/dialog_helpers.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/cta_reserved_space.dart';
import '../../../shared/widgets/ds_error_state.dart';
import '../../../shared/widgets/ds_picker_sheet.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../../houses/model/house_model.dart';
import '../../houses/providers/house_provider.dart';
import '../../items/model/item_model.dart';
import '../../items/providers/item_provider.dart';
import '../../tour/tour_keys.dart';
import '../helpers/ai_item_category.dart';
import '../model/clothing_analysis_result.dart';
import '../model/ai_failure_reason.dart';
import '../model/ai_import_state.dart';
import '../helpers/start_ai_scan.dart';
import '../providers/ai_import_notifier.dart';
import 'widgets/ai_analysis_progress.dart';
import 'widgets/ai_photo_group_header.dart';
import 'widgets/ai_result_card.dart';
import 'widgets/image_source_sheet.dart';

/// Page 2 of the AI import flow: shows loading progress while GPT-4o Vision
/// analyses the images, then the editable results list with save CTA.
///
/// Normal scans arrive through [startAiScan]; the onboarding scan arrives
/// through [AiOnboardingIntroScreen]. Both start processing before navigation.
class AiResultsScreen extends ConsumerStatefulWidget {
  final String? houseId;
  final bool isFirstTimeOnboarding;

  const AiResultsScreen({
    super.key,
    this.houseId,
    required this.isFirstTimeOnboarding,
  });

  @override
  ConsumerState<AiResultsScreen> createState() => _AiResultsScreenState();
}

class _AiResultsScreenState extends ConsumerState<AiResultsScreen> {
  final List<List<TextEditingController>> _controllers = [];
  bool _onboardingTooltipShown = false;
  bool _pickerOpen = false;
  bool _exitDialogOpen = false;
  bool _allowProgrammaticPop = false;
  bool _exitStarted = false;
  bool _saveRequested = false;

  @override
  void initState() {
    super.initState();
    _syncControllers(ref.read(aiImportNotifierProvider));
  }

  @override
  void dispose() {
    for (final group in _controllers) {
      for (final c in group) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _syncControllers(AiImportState next) {
    while (_controllers.length < next.photoGroups.length) {
      final gi = _controllers.length;
      _controllers.add(
        next.photoGroups[gi].results
            .map((r) => TextEditingController(text: r.name))
            .toList(),
      );
    }
    while (_controllers.length > next.photoGroups.length) {
      for (final c in _controllers.last) {
        c.dispose();
      }
      _controllers.removeLast();
    }
    for (var gi = 0; gi < _controllers.length; gi++) {
      final resultCount = next.photoGroups[gi].results.length;
      while (_controllers[gi].length < resultCount) {
        final ii = _controllers[gi].length;
        _controllers[gi].add(
          TextEditingController(text: next.photoGroups[gi].results[ii].name),
        );
      }
      while (_controllers[gi].length > resultCount) {
        _controllers[gi].last.dispose();
        _controllers[gi].removeLast();
      }
    }

    // Niente selezione automatica del primo campo. Selezionare tutto il testo
    // segnalava che il campo è editabile, ma su una schermata di *revisione*
    // costava più di quanto rendesse: il primo suggerimento appariva
    // evidenziato (sembrava un artefatto grafico) e il primo tasto premuto lo
    // cancellava per intero. Che i campi siano editabili lo dicono già il
    // bordo a pill e l'icona di eliminazione accanto.
  }

  // ── Picker (add more photos) ──────────────────────────────────────────────

  Future<void> _showPickerSheet() async {
    if (!mounted) return;
    if (_pickerOpen || ref.read(aiImportNotifierProvider).isLoading) return;
    _pickerOpen = true;
    final notifier = ref.read(aiImportNotifierProvider.notifier);
    try {
      if (notifier.remainingSlots <= 0) return;
      final source = await showImageSourceSheet(
        context,
        gallerySubtitle: 'ai_import.gallery_subtitle'.tr(
          args: [notifier.remainingSlots.toString()],
        ),
        cameraSubtitle: 'ai_import.camera_subtitle'.tr(),
      );
      if (!mounted) return;
      switch (source) {
        case ImageSource.gallery:
          await _pickFromGallery();
        case ImageSource.camera:
          await _pickFromCamera();
        case null:
          return;
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('ai_picker_error'),
            content: Text('ai_import.picker_error'.tr()),
            action: SnackBarAction(
              label: 'ai_import.picker_retry'.tr(),
              onPressed: () {
                if (!mounted) return;
                _showPickerSheet();
              },
            ),
          ),
        );
      }
    } finally {
      _pickerOpen = false;
    }
  }

  Future<void> _pickFromGallery() async {
    final notifier = ref.read(aiImportNotifierProvider.notifier);
    final remainingSlots = notifier.remainingSlots;
    if (remainingSlots <= 0) return;
    final picker = ImagePicker();
    if (remainingSlots == 1) {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      await notifier.processFiles([File(picked.path)]);
      return;
    }
    final pickedFiles = await picker.pickMultiImage(
      imageQuality: 80,
      limit: remainingSlots,
    );
    if (pickedFiles.isEmpty || !mounted) return;
    await notifier.processFiles(
      pickedFiles.take(remainingSlots).map((file) => File(file.path)).toList(),
    );
  }

  Future<void> _pickFromCamera() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    await ref.read(aiImportNotifierProvider.notifier).processFiles([
      File(picked.path),
    ]);
  }

  // ── Uscita dal flusso ─────────────────────────────────────────────────────

  /// Nomi delle route che compongono il flusso di scansione (vedi
  /// `app_router.dart`): sono quelle da togliere dallo stack in uscita.
  static const _flowRouteNames = {'ai-import-results'};

  /// Chiude il flusso e lascia lo stack come [shell, dettaglio casa].
  ///
  /// Non usa `go()`: rimpiazzerebbe lo stack radice con il solo dettaglio, la
  /// shell sparirebbe e il tasto indietro di Android chiuderebbe l'app. Toglie
  /// invece le route del flusso e apre il dettaglio solo se quello che resta in
  /// cima non è già il dettaglio della stessa casa (flusso partito da lì).
  void _exitToHouse() {
    final houseId = widget.houseId;
    if (houseId == null) return;
    if (_exitStarted || ref.read(aiImportNotifierProvider).isLoading) return;
    _exitStarted = true;
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    if (!_allowProgrammaticPop) {
      setState(() => _allowProgrammaticPop = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Route<dynamic>? remaining;
      navigator.popUntil((route) {
        final isFlowRoute = _flowRouteNames.contains(route.settings.name);
        if (!isFlowRoute) remaining = route;
        return !isFlowRoute;
      });

      final args = remaining?.settings.arguments;
      final isSameHouseDetail =
          remaining?.settings.name == 'house-detail' &&
          args is Map &&
          args['id'] == houseId;
      if (!isSameHouseDetail) router.push('/houses/$houseId');
    });
  }

  Future<void> _confirmExit() async {
    final state = ref.read(aiImportNotifierProvider);
    if (state.isLoading || _exitDialogOpen || _exitStarted) return;
    final notifier = ref.read(aiImportNotifierProvider.notifier);
    if (notifier.newCount + notifier.updatedCount > 0) {
      _exitDialogOpen = true;
      try {
        final confirmed = await DialogHelpers.showConfirmation(
          context: context,
          title: 'ai_import.discard_title'.tr(),
          message: 'ai_import.discard_body'.tr(),
          confirmLabel: 'ai_import.discard'.tr(),
          isDestructive: true,
        );
        if (!confirmed || !mounted) return;
      } finally {
        _exitDialogOpen = false;
      }
    }
    _exitToHouse();
  }

  // ── Onboarding tooltip ────────────────────────────────────────────────────

  void _showAiSaveTooltip() {
    if (_onboardingTooltipShown) return;
    setState(() => _onboardingTooltipShown = true);
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'ai_save_tooltip',
          keyTarget: tourKeys.infoCardTarget,
          shape: ShapeLightFocus.Circle,
          radius: 1,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (ctx, controller) {
                final colorScheme = Theme.of(context).colorScheme;
                final textTheme = Theme.of(context).textTheme;
                return Container(
                  padding: EdgeInsets.all(context.spacingMd),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(
                      AppConstants.cardBorderRadius,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'onboarding_tour.ai_save_tooltip'.tr(),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: context.spacingMd),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () => controller.next(),
                          child: Text('tour.finish'.tr()),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.8,
      hideSkip: true,
    ).show(context: context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiImportNotifierProvider);
    final notifier = ref.read(aiImportNotifierProvider.notifier);

    ref.listen<AiImportState>(aiImportNotifierProvider, (prev, next) {
      _syncControllers(next);

      if (widget.isFirstTimeOnboarding &&
          next.photoGroups.isNotEmpty &&
          !_onboardingTooltipShown) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAiSaveTooltip();
        });
      }

      // Il conteggio del vecchio stato includeva esclusi e collegati. Il
      // repository può anche saltare un aggiornamento concorrente, quindi il
      // messaggio di esito resta generico.
      if (_saveRequested &&
          prev != null &&
          prev.isLoading &&
          prev.photoGroups.isNotEmpty &&
          !next.isLoading &&
          next.photoGroups.isEmpty &&
          next.failureReason == null &&
          next.errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ai_import.save_success_generic'.tr()),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (!widget.isFirstTimeOnboarding && widget.houseId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _exitToHouse();
          });
        }
        // In onboarding mode the router redirect handles navigation when
        // the onboarding step advances inside saveItemsOnboarding().
      }
    });

    return PopScope<Object?>(
      canPop: widget.isFirstTimeOnboarding || _allowProgrammaticPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || widget.isFirstTimeOnboarding || aiState.isLoading) return;
        _confirmExit();
      },
      child: StickyCtaScaffold(
        appBar: AppBar(
          title: Text('ai_import.title'.tr()),
          leading: widget.isFirstTimeOnboarding || widget.houseId == null
              ? null
              : IconButton(
                  key: const Key('ai_results_close'),
                  icon: const Icon(Icons.close),
                  tooltip: 'common.close'.tr(),
                  onPressed: aiState.isLoading || _exitStarted
                      ? null
                      : _confirmExit,
                ),
        ),
        // Builder: ctaReservedHeight legge CtaReservedSpaceScope, che
        // StickyCtaScaffold inserisce come discendente di `body` — serve un
        // context interno a questo subtree, non quello del metodo build
        // esterno (che sta sopra lo scope e non lo vedrebbe mai).
        body: Builder(
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                context.spacingMd,
              ).copyWith(bottom: context.spacingMd + context.ctaReservedHeight),
              child: _buildBody(context, aiState, notifier),
            ),
          ),
        ),
        bottomContent: _buildBottomContent(context, aiState, notifier),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AiImportState state,
    AiImportNotifier notifier,
  ) {
    if (state.isLoading) return _buildLoading(context, state);
    if (state.photoGroups.isEmpty) {
      return _buildEmptyError(context, state, notifier);
    }
    return _buildResults(context, state, notifier);
  }

  // ── Bottom CTA ────────────────────────────────────────────────────────────

  Widget? _buildBottomContent(
    BuildContext context,
    AiImportState state,
    AiImportNotifier notifier,
  ) {
    if (state.isLoading) return null;
    if (state.photoGroups.isEmpty) return null;
    return _buildResultsBar(context, state, notifier);
  }

  // ── Results bottom bar ────────────────────────────────────────────────────

  Widget _buildResultsBar(
    BuildContext context,
    AiImportState state,
    AiImportNotifier notifier,
  ) {
    final totalItems = state.photoGroups.expand((g) => g.results).length;

    // AI found nothing: offer to pick another photo instead of a useless save.
    if (totalItems == 0) {
      return UniversalActionBar(
        primaryLabel: 'ai_import.retry_photo'.tr(),
        primaryIcon: Icons.add_photo_alternate_outlined,
        onPrimaryPressed: _showPickerSheet,
      );
    }

    final newCount = notifier.newCount;
    final updatedCount = notifier.updatedCount;
    final selectedHouse = widget.isFirstTimeOnboarding
        ? null
        : _selectedHouse(state.selectedHouseId);
    final canSave =
        !state.isLoading &&
        newCount + updatedCount > 0 &&
        (widget.isFirstTimeOnboarding || selectedHouse != null);
    final label = switch ((newCount, updatedCount)) {
      (0, 0) => 'common.save'.tr(),
      (_, 0) => 'ai_import.save_new'.plural(newCount),
      (0, _) => 'ai_import.save_updated'.plural(updatedCount),
      _ =>
        '${'ai_import.save_new'.plural(newCount)} · '
            '${'ai_import.updated_part'.plural(updatedCount)}',
    };

    return UniversalActionBar(
      primaryLabel: label,
      isLoading: state.isLoading,
      onPrimaryPressed: canSave ? () => _saveResults(notifier) : null,
    );
  }

  Future<void> _saveResults(AiImportNotifier notifier) async {
    _saveRequested = true;
    try {
      if (widget.isFirstTimeOnboarding) {
        await notifier.saveItemsOnboarding();
      } else {
        await notifier.saveItems();
      }
    } finally {
      _saveRequested = false;
    }
  }

  HouseModel? _selectedHouse(String? id) {
    if (id == null) return null;
    return ref
        .watch(houseNotifierProvider)
        .when(
          data: (houses) => houses.where((house) => house.id == id).firstOrNull,
          loading: () => null,
          error: (_, _) => null,
        );
  }

  Future<void> _showHousePicker(
    AiImportState state,
    AiImportNotifier notifier,
  ) async {
    final houses = ref
        .read(houseNotifierProvider)
        .when(
          data: (items) => items,
          loading: () => const <HouseModel>[],
          error: (_, _) => const <HouseModel>[],
        );
    if (houses.isEmpty) return;

    final selected = await DsPickerSheet.show<HouseModel>(
      context: context,
      title: 'ai_import.choose_house_title'.tr(),
      items: houses,
      getLabel: (h) => h.displayName,
      getIcon: (_) => Icons.home_outlined,
      selected: houses.where((h) => h.id == state.selectedHouseId).firstOrNull,
    );
    if (selected != null) notifier.setSelectedHouseId(selected.id);
  }

  bool _hasSameCategory(
    List<ItemModel>? items,
    ClothingAnalysisResult result,
  ) =>
      items?.any((item) => item.category == aiItemCategory(result.category)) ??
      false;

  String? _linkedName(String? id, List<ItemModel>? items) {
    if (id == null || items == null) return null;
    return items.where((item) => item.id == id).firstOrNull?.name;
  }

  /// Il foglio informativo viene implementato nel task 4.
  Future<void> _openAlreadyHere(
    AiImportState state,
    int groupIndex,
    int itemIndex,
  ) async {}

  // ── Loading state ─────────────────────────────────────────────────────────

  Widget _buildLoading(BuildContext context, AiImportState state) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: context.screenHeight * 0.6,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sopra la barra: dice cosa sta succedendo e perché conviene restare.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
            child: Text(
              'ai_import.analysis_in_progress'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: context.spacingMd),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
            child: AiAnalysisProgress(
              processingIndex: state.processingIndex,
              totalImages: state.totalImages,
              avgPhotoMs: state.avgPhotoMs,
            ),
          ),
          SizedBox(height: context.spacingLg),
          Text(
            state.totalImages > 0
                ? 'ai_import.loading_progress'.tr(
                    args: [
                      state.processingIndex.toString(),
                      state.totalImages.toString(),
                    ],
                  )
                : 'ai_import.loading'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (state.photoGroups.isNotEmpty) ...[
            SizedBox(height: context.spacingMd),
            Text(
              'ai_import.items_found_so_far'.tr(
                args: [
                  state.photoGroups.expand((g) => g.results).length.toString(),
                ],
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty / error on Page 2 ───────────────────────────────────────────────

  /// Errore terminale: nessun risultato in mano, la pagina è vuota.
  ///
  /// Usa `DsErrorState` — lo stato d'errore condiviso dell'app — invece del
  /// riquadro rosso locale: qui l'utente resta senza nulla e serve un'azione
  /// che persista, non una segnalazione che passa. Il messaggio arriva da
  /// [AiFailureReason], quindi niente dettagli tecnici né URI a schermo.
  Widget _buildEmptyError(
    BuildContext context,
    AiImportState state,
    AiImportNotifier notifier,
  ) {
    final reason = state.failureReason;
    if (reason == null) return const SizedBox.shrink();

    return SizedBox(
      height: context.screenHeight * 0.6,
      child: DsErrorState(
        error: reason,
        message: reason.messageKey.tr(),
        retryLabel: 'ai_import.retry'.tr(),
        // Su quota esaurita e sessione scaduta riprovare non può funzionare:
        // DsErrorState richiede una callback, quindi in quei casi la rendiamo
        // un no-op e il pulsante non viene mostrato.
        onRetry: reason.isRetryable ? notifier.retryFailed : () {},
        showRetry: reason.isRetryable,
      ),
    );
  }

  // ── Results state ─────────────────────────────────────────────────────────

  Widget _buildResults(
    BuildContext context,
    AiImportState state,
    AiImportNotifier notifier,
  ) {
    final allResults = state.photoGroups.expand((g) => g.results).toList();
    final colorScheme = Theme.of(context).colorScheme;
    final selectedHouse = widget.isFirstTimeOnboarding
        ? null
        : _selectedHouse(state.selectedHouseId);
    final existingItems =
        !widget.isFirstTimeOnboarding && state.selectedHouseId != null
        ? ref
              .watch(itemNotifierProvider(state.selectedHouseId!))
              .when(
                data: (items) => items,
                loading: () => null,
                error: (_, _) => null,
              )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: context.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Intestazione grigia: è un conteggio, non un'azione. In
                  // arancione competeva con la CTA di salvataggio, che in
                  // questa schermata deve restare l'unica cosa colorata.
                  Icon(
                    Icons.checkroom_outlined,
                    size: context.iconSizeSm,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: context.spacingXs),
                  Text(
                    'ai_import.items_identified'.plural(allResults.length),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacingXs),
              Text(
                'ai_import.rename_hint'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (selectedHouse != null) ...[
                SizedBox(height: context.spacingXs),
                InkWell(
                  key: const Key('ai_destination'),
                  borderRadius: BorderRadius.circular(
                    AppConstants.pillBorderRadius,
                  ),
                  onTap: state.isLoading
                      ? null
                      : () => _showHousePicker(state, notifier),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: context.spacingXs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          HouseIcons.getIcon(selectedHouse.iconName),
                          size: context.iconSizeSm,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: context.spacingXs),
                        Flexible(
                          child: Text(
                            'create_sheet.in_house'.tr(
                              args: [selectedHouse.displayName],
                            ),
                            style: Theme.of(context).textTheme.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.expand_more,
                          size: context.iconSizeSm,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        for (var gi = 0; gi < state.photoGroups.length; gi++) ...[
          AiPhotoGroupHeader(
            photo: state.photoGroups[gi].photo,
            photoIndex: gi + 1,
            itemCount: state.photoGroups[gi].results.length,
          ),
          if (gi < _controllers.length)
            for (var ii = 0; ii < state.photoGroups[gi].results.length; ii++)
              if (ii < _controllers[gi].length)
                Padding(
                  padding: EdgeInsets.only(bottom: context.spacingMd),
                  child: AiResultCard(
                    key: ValueKey('ai_result_${gi}_$ii'),
                    item: state.photoGroups[gi].results[ii],
                    controller: _controllers[gi][ii],
                    onNameChanged: (value) =>
                        notifier.updateItemName(gi, ii, value),
                    included: !state.photoGroups[gi].excluded.contains(ii),
                    onIncludedChanged: (included) =>
                        notifier.setIncluded(gi, ii, included),
                    isLinked: state.photoGroups[gi].linkedItemIds.containsKey(
                      ii,
                    ),
                    linkedItemName: _linkedName(
                      state.photoGroups[gi].linkedItemIds[ii],
                      existingItems,
                    ),
                    onUnlink:
                        state.photoGroups[gi].linkedItemIds.containsKey(ii)
                        ? () => notifier.unlink(gi, ii)
                        : null,
                    onAlreadyHere:
                        _hasSameCategory(
                          existingItems,
                          state.photoGroups[gi].results[ii],
                        )
                        ? () => _openAlreadyHere(state, gi, ii)
                        : null,
                    enabled: !state.isLoading,
                  ),
                ),
          if (state.photoGroups[gi].results.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacingMd),
              child: Text(
                'ai_import.no_items_found_in_photo'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],

        // Errore non terminale: qualche foto è riuscita, quindi la pagina
        // resta utilizzabile e l'errore è un avviso, non uno stato. Il retry
        // riprende solo dalle foto mancanti.
        if (state.failureReason != null || state.errorMessage != null) ...[
          SizedBox(height: context.spacingMd),
          Container(
            padding: EdgeInsets.all(context.spacingMd),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(
                AppConstants.inputBorderRadius,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: context.iconSizeSm,
                  color: colorScheme.onErrorContainer,
                ),
                SizedBox(width: context.spacingSm),
                Expanded(
                  child: Text(
                    state.failureReason?.messageKey.tr() ?? state.errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                if (state.failureReason?.isRetryable ?? false) ...[
                  SizedBox(width: context.spacingSm),
                  TextButton(
                    key: const Key('ai_partial_error_retry'),
                    onPressed: notifier.retryFailed,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onErrorContainer,
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                    ),
                    child: Text('ai_import.retry'.tr()),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
