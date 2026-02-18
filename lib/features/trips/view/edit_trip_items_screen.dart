import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
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
      errorTitle: 'Errore di salvataggio',
      errorMessage: 'Impossibile salvare gli oggetti del viaggio.',
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modifica oggetti')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifica oggetti'),
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
                '${_selectedItems.length} oggetti',
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
      body: Stack(
        children: [
          // Widget riutilizzabile per la selezione degli items
          Padding(
            padding: EdgeInsets.only(
              left: context.spacingSm,
              right: context.spacingSm,
              top: context.spacingSm,
            ),
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
          
          // Bottone fisso in basso
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(context.spacingMd),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: _buildSaveButton(context, colorScheme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(28),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _isLoading ? null : _saveChanges,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colorScheme.primary, width: 2),
          ),
          child: Center(
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, color: colorScheme.onSurfaceVariant),
                      SizedBox(width: context.spacingSm),
                      Text(
                        'Salva oggetti',
                        style: TextStyle(
                          fontSize: context.fontSizeMd,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
