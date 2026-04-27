import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_spacing.dart';
import '../domain/packing_blueprint_engine.dart';
import '../domain/packing_inventory_service.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../services/open_meteo_service.dart';
import '../services/smart_packing_agent.dart';
import 'smart_packing_results_screen.dart';

/// Engaging loading screen shown while the AI packing pipeline runs.
///
/// Two modes:
/// - **Creation** (`pendingTrip != null`): trip data comes directly from the
///   form without a DB round-trip. The trip is NOT saved until the user
///   confirms in the results screen.
/// - **Edit** (`pendingTrip == null`): trip is read from [TripNotifier] by
///   [tripId] as usual.
///
/// Pipeline steps:
///   1. Resolve trip model (from param or DB).
///   2. Fetch weather via [OpenMeteoService] if missing.
///   3. Compute base quotas via [PackingBlueprintEngine].
///   4. Pre-screen inventory via [PackingInventoryService].
///   5. Generate wardrobe recommendations via [SmartPackingAgent].
///   6. Append essentials deterministically (no AI).
///   7. Navigate to [SmartPackingResultsScreen] on success.
class SmartPackingLoadingScreen extends ConsumerStatefulWidget {
  final String tripId;

  /// Trip data passed directly from the creation form.
  /// When non-null the pipeline skips the DB lookup.
  final TripModel? pendingTrip;

  const SmartPackingLoadingScreen({
    super.key,
    required this.tripId,
    this.pendingTrip,
  });

  @override
  ConsumerState<SmartPackingLoadingScreen> createState() =>
      _SmartPackingLoadingScreenState();
}

class _SmartPackingLoadingScreenState
    extends ConsumerState<SmartPackingLoadingScreen>
    with SingleTickerProviderStateMixin {
  // ── Cycling messages ──────────────────────────────────────────────────────

  static const _messages = [
    'Analizzando il meteo a destinazione...',
    'Scansionando il guardaroba...',
    'Scegliendo gli abbinamenti perfetti...',
    'Verificando le quote bagaglio...',
    'Consultando lo stilista virtuale...',
    'Incastrando tutto in valigia...',
    'Quasi pronto...',
  ];

  int _messageIndex = 0;
  Timer? _messageTimer;

  // ── Pulse animation ───────────────────────────────────────────────────────

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // ── State ─────────────────────────────────────────────────────────────────

  bool _hasError = false;
  String? _errorMessage;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _messageTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _messages.length;
        });
      }
    });

    // Defer to ensure the widget tree is fully built before triggering
    // async work that reads providers.
    // The Future is explicitly caught here so that any uncaught error in
    // _runPipeline does NOT silently become an unhandled Future error (which
    // can terminate the process on some Android configurations).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runPipeline().catchError((Object e, StackTrace st) {
        debugPrint('[SmartPacking] Unhandled pipeline error: $e\n$st');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = e.toString();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  // ── Pipeline ──────────────────────────────────────────────────────────────

  Future<void> _runPipeline() async {
    if (mounted) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
    }

    try {
      // Top-level timeout di sicurezza: se per qualunque motivo (rete lenta,
      // problemi runtime emulatore, hang inatteso) la pipeline non finisce in
      // 90 secondi, mostriamo l'error screen invece di lasciare l'utente
      // bloccato sullo spinner all'infinito.
      await _runPipelineInternal().timeout(const Duration(seconds: 90));
    } catch (e, st) {
      debugPrint('[SmartPacking] Pipeline error: $e\n$st');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _runPipelineInternal() async {
    debugPrint('[SmartPacking] ▶ Pipeline started');

    // Step 1 — Resolve trip (form data or DB)
    TripModel trip;
    if (widget.pendingTrip != null) {
      trip = widget.pendingTrip!;
      debugPrint('[SmartPacking] Step 1 ✓ pendingTrip resolved');
    } else {
      final trips = ref.read(tripNotifierProvider).value;
      final found = trips?.firstWhere(
        (t) => t.id == widget.tripId,
        orElse: () => throw StateError('Viaggio non trovato'),
      );
      if (found == null) throw StateError('Viaggio non trovato');
      trip = found;
      debugPrint('[SmartPacking] Step 1 ✓ trip loaded from DB');
    }

    // Step 2 — Fetch weather if missing
    debugPrint('[SmartPacking] Step 2 — fetching weather...');
    if (trip.weatherTags.isEmpty) {
      trip = await _enrichWithWeather(trip);
    }
    debugPrint('[SmartPacking] Step 2 ✓ weatherTags=${trip.weatherTags}');

    // Step 3 — Compute duration and base quotas
    final duration = _computeDuration(trip);
    final quotas = PackingBlueprintEngine(
      tripDurationDays: duration,
      primaryVibe: trip.primaryVibe,
    ).calculateBaseQuotas();
    debugPrint('[SmartPacking] Step 3 ✓ duration=$duration quotas=$quotas');

    // Step 4 — Pre-screen inventory
    debugPrint('[SmartPacking] Step 4 — loading inventory...');
    final inventoryService = ref.read(packingInventoryServiceProvider);
    final buckets = await inventoryService.getFilteredInventoryForTrip(
      trip.weatherTags,
    );
    debugPrint(
      '[SmartPacking] Step 4 ✓ wardrobe=${buckets.wardrobe.length} '
      'essentials=${buckets.essentials.length}',
    );

    // Step 5 — AI generation (wardrobe only)
    final agent = ref.read(smartPackingAgentProvider);
    final destination = _resolveDestination(trip);
    debugPrint(
      '[SmartPacking] Step 5 — calling GPT-4o-mini for "$destination"...',
    );

    final wardrobeRecs = await agent
        .generatePackingList(
          destination: destination,
          tripDurationDays: duration,
          weatherTags: trip.weatherTags,
          quotas: quotas,
          wardrobeBucket: buckets.wardrobe,
          pastTripsJson: '[]',
        )
        .timeout(const Duration(seconds: 45));
    debugPrint('[SmartPacking] Step 5 ✓ ${wardrobeRecs.length} wardrobe recs');

    // Step 6 — Append essentials deterministically (no AI needed)
    final essentialRecs = buckets.essentials.map(
      (item) => SmartPackingRecommendation(
        itemId: item.id,
        quantityToTake: item.quantity ?? 1,
        motivation: 'Articolo essenziale per il viaggio.',
      ),
    );

    // Deduplica per itemId: il modello GPT può raccomandare lo stesso item
    // più volte, e un item non può comparire due volte nello stesso viaggio
    // (PK composta su trip_item_entries.(id, trip_id)).
    final seen = <String>{};
    final recommendations = [
      ...wardrobeRecs,
      ...essentialRecs,
    ].where((r) => r.itemId.isNotEmpty && seen.add(r.itemId)).toList();
    debugPrint(
      '[SmartPacking] Step 6 ✓ total=${recommendations.length} items '
      '(after dedup)',
    );

    if (!mounted) return;

    debugPrint('[SmartPacking] ▶ Navigating to results screen...');
    context.pushReplacement(
      '/trips/${widget.tripId}/smart-packing/results',
      extra: SmartPackingResultsPayload(
        recommendations: recommendations,
        pendingTrip: widget.pendingTrip,
      ),
    );
    debugPrint('[SmartPacking] ✅ Pipeline complete');
  }

  /// Fetches weather from OpenMeteo and enriches [trip] with weatherTags
  /// and avgTemperature. Returns [trip] unchanged on any failure.
  Future<TripModel> _enrichWithWeather(TripModel trip) async {
    final lat = trip.destinationLocation?.lat;
    final lon = trip.destinationLocation?.lon;
    final startDate = trip.departureDateTime;
    if (lat == null || lon == null || startDate == null) return trip;

    try {
      final service = ref.read(openMeteoServiceProvider);
      final endDate = trip.returnDateTime ?? startDate;
      final weather = await service
          .fetchWeather(
            lat: lat,
            lon: lon,
            startDate: startDate,
            endDate: endDate,
          )
          .timeout(const Duration(seconds: 5));

      debugPrint(
        '[SmartPacking] Weather: ${weather.avgTemp}°C, ${weather.weatherTags}',
      );

      return trip.copyWith(
        avgTemperature: weather.avgTemp,
        weatherTags: weather.weatherTags,
      );
    } catch (e) {
      debugPrint('[SmartPacking] Weather fetch skipped: $e');
      return trip;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int _computeDuration(TripModel trip) {
    final dep = trip.departureDateTime;
    final ret = trip.returnDateTime;
    if (dep == null) return 3; // default for undated trips
    if (ret == null) return 1;
    return ret.difference(dep).inDays.clamp(1, 90);
  }

  String _resolveDestination(TripModel trip) {
    return trip.destinationDisplayName ??
        trip.destinationLocation?.displayName ??
        'Destinazione sconosciuta';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Packing AI'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _hasError ? _buildError(context) : _buildLoading(context),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing AI brain icon
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, child) =>
                  Transform.scale(scale: _pulseAnimation.value, child: child),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Spinning progress indicator (secondary, small)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.primary,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Cycling message with fade transition
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Text(
                _messages[_messageIndex],
                key: ValueKey(_messageIndex),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Decorative error icon
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: colorScheme.error,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Text(
              'Ops, qualcosa è andato storto',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              'Non è stato possibile generare la lista.\nControllare la connessione e riprovare.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
              onPressed: _runPipeline,
            ),

            const SizedBox(height: AppSpacing.sm),

            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Annulla'),
            ),
          ],
        ),
      ),
    );
  }
}
