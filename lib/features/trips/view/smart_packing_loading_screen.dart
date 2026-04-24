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

/// Engaging loading screen shown while the AI packing pipeline runs.
///
/// Pipeline steps (all on this screen):
///   1. Read trip data from [TripNotifier].
///   2. Compute base quotas via [PackingBlueprintEngine].
///   3. Pre-screen inventory via [PackingInventoryService].
///   4. Generate recommendations via [SmartPackingAgent].
///   5. Navigate to [SmartPackingResultsScreen] on success, or show an error
///      state with a retry button on failure.
///
/// The user sees a pulsing icon and cycling text while waiting.
class SmartPackingLoadingScreen extends ConsumerStatefulWidget {
  final String tripId;

  const SmartPackingLoadingScreen({super.key, required this.tripId});

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

    _messageTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        if (mounted) {
          setState(() {
            _messageIndex = (_messageIndex + 1) % _messages.length;
          });
        }
      },
    );

    // Defer to ensure the widget tree is fully built before triggering
    // async work that reads providers.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPipeline());
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
      // Step 1 — Resolve trip
      final trips = ref.read(tripNotifierProvider).value;
      final trip = trips?.firstWhere(
        (t) => t.id == widget.tripId,
        orElse: () => throw StateError('Viaggio non trovato'),
      );
      if (trip == null) throw StateError('Viaggio non trovato');

      // Step 2 — Compute duration and base quotas
      final duration = _computeDuration(trip);
      final quotas = PackingBlueprintEngine(
        tripDurationDays: duration,
        primaryVibe: trip.primaryVibe,
      ).calculateBaseQuotas();

      // Step 3 — Pre-screen inventory
      final inventoryService = ref.read(packingInventoryServiceProvider);
      final buckets = await inventoryService.getFilteredInventoryForTrip(
        trip.weatherTags,
      );

      // Step 4 — AI generation (15 s timeout, graceful on error)
      final agent = ref.read(smartPackingAgentProvider);
      final destination = _resolveDestination(trip);

      final recommendations = await agent
          .generatePackingList(
            destination: destination,
            tripDurationDays: duration,
            weatherTags: trip.weatherTags,
            quotas: quotas,
            wardrobeBucket: buckets.wardrobe,
            essentialsBucket: buckets.essentials,
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      context.pushReplacement(
        '/trips/${widget.tripId}/smart-packing/results',
        extra: recommendations,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
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
    final colorScheme = Theme.of(context).colorScheme;

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
              builder: (_, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              ),
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
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: child,
              ),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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

