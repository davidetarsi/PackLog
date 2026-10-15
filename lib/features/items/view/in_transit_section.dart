import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pack_log/features/items/view/in_transit_item_card.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/shared/widgets/ds_group_header.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/widgets/ds_group_surface_sliver.dart';

/// Gruppo "Temporanei" della lista della casa.
///
/// Stesso schema dei gruppi per categoria: etichetta fissa in alto e tocco
/// per chiudere o riaprire.
class InTransitSection extends StatefulWidget {
  final List<TripItem> items;
  final List<HouseModel> houses;

  /// Key dell'etichetta (il tour la usa come bersaglio quando è il primo gruppo).
  final Key? headerKey;

  const InTransitSection({
    super.key,
    required this.items,
    required this.houses,
    this.headerKey,
  });

  @override
  State<InTransitSection> createState() => _InTransitSectionState();
}

class _InTransitSectionState extends State<InTransitSection> {
  bool _isExpanded = true;

  /// Nome della casa di provenienza di un item, o il fallback tradotto.
  String _originName(TripItem item) {
    final match = widget.houses.where((h) => h.id == item.originHouseId);
    return match.isNotEmpty
        ? match.first.displayName
        : 'common.unknown_house'.tr();
  }

  @override
  Widget build(BuildContext context) {
    // Quando i temporanei vengono tutti dalla stessa casa — il caso
    // normale — la provenienza sale nell'etichetta invece di ripetersi su ogni
    // riga. Con provenienze miste non è riassumibile e resta per riga.
    final origins = widget.items.map(_originName).toSet();
    final sharedOrigin = origins.length == 1 ? origins.first : null;

    return SliverMainAxisGroup(
      slivers: [
        PinnedHeaderSliver(
          child: DsGroupHeader(
            key: widget.headerKey,
            label: 'common.temporaries'.tr(),
            count: widget.items.length,
            prominent: true,
            detail: sharedOrigin == null
                ? null
                : '${'common.from'.tr().toLowerCase()} $sharedOrigin',
            expanded: _isExpanded,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
        ),
        if (_isExpanded)
          DsGroupSurfaceSliver(
            surfaceKey: const ValueKey('house_group_surface_temporaries'),
            sliver: SliverList.builder(
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return InTransitItemCard(
                  item: item,
                  originHouseName: _originName(item),
                  showOrigin: sharedOrigin == null,
                  dividerInsets: EdgeInsets.symmetric(
                    horizontal: context.spacingMd,
                  ),
                  showDivider: index < widget.items.length - 1,
                );
              },
            ),
          ),
      ],
    );
  }
}
