import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import 'trip_items_selector.dart';

/// Schermata per modificare solo gli oggetti del viaggio.
class EditTripItemsScreen extends ConsumerStatefulWidget {
  final String tripId;

  const EditTripItemsScreen({super.key, required this.tripId});

  @override
  ConsumerState<EditTripItemsScreen> createState() => _EditTripItemsScreenState();
}

class _EditTripItemsScreenState extends ConsumerState<EditTripItemsScreen> {
  bool _isLoading = false;
  TripModel? _trip;
  List<TripItem> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  void _loadTrip() {
    final tripsAsync = ref.read(tripNotifierProvider);
    tripsAsync.whenData((trips) {
      final trip = trips.where((t) => t.id == widget.tripId).firstOrNull;
      if (trip != null) {
        setState(() {
          _trip = trip;
          _selectedItems = List.from(trip.items);
        });
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_trip == null) return;

    setState(() => _isLoading = true);

    final updatedTrip = _trip!.copyWith(
      items: _selectedItems,
      updatedAt: DateTime.now(),
    );

    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () => ref.read(tripNotifierProvider.notifier).updateTrip(updatedTrip),
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: 'errors.save_trip_items_failed'.tr(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.go('/trips/${widget.tripId}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: Text('trips.edit_items'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return StickyCtaScaffold(
      appBar: AppBar(
        title: Text('trips.edit_items'.tr()),
        actions: [
          Center(
            child: Container(
              margin: EdgeInsets.only(right: context.spacingMd),
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingSm,
                vertical: context.spacingXs,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: context.responsiveBorderRadius(12),
              ),
              child: Text(
                'common.items_count'.tr(args: [_selectedItems.length.toString()]),
                style: TextStyle(
                  fontSize: context.fontSizeXs,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(context.spacingMd),
        child: TripItemsSelector(
          selectedItems: _selectedItems,
          onSelectionChanged: (items) {
            setState(() {
              _selectedItems = items;
            });
          },
          shrinkWrap: false,
        ),
      ),
      bottomContent: UniversalActionBar(
        primaryLabel: 'trips.save_items'.tr(),
        primaryIcon: Icons.save,
        onPrimaryPressed: _isLoading ? null : _saveChanges,
        isLoading: _isLoading,
      ),
    );
  }
}
