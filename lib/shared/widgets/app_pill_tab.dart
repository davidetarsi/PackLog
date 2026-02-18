import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme.dart';

/// Widget riutilizzabile per pill-style tabs con supporto per due comportamenti:
/// - Standard: almeno un item deve essere selezionato
/// - Nullable: può deselezionare (toggle behavior)
///
/// Esempio standard:
/// ```dart
/// AppPillTab<Status>(
///   items: Status.values,
///   selectedItem: _status,
///   getLabel: (s) => s.label,
///   onSelected: (s) => setState(() => _status = s),
/// )
/// ```
///
/// Esempio nullable (toggle):
/// ```dart
/// AppPillTab<Category>.nullable(
///   items: Category.values,
///   selectedItem: _category,
///   getLabel: (c) => c.name,
///   onSelected: (c) => setState(() => _category = c),
/// )
/// ```
class AppPillTab<T> extends StatelessWidget {
  final List<T> items;
  final T? selectedItem;
  final String Function(T) getLabel;
  final Widget? Function(T)? getIcon;
  final Function onSelected;  // ValueChanged<T> or ValueChanged<T?>
  final bool allowDeselect;
  
  // Styling options
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final double? horizontalPadding;
  final double? verticalPadding;
  final double? spacing;
  final double? height;
  final EdgeInsets? scrollPadding;

  /// Costruttore standard: almeno un item deve essere selezionato.
  /// Tap su item già selezionato non fa nulla.
  const AppPillTab({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.getLabel,
    required this.onSelected,
    this.getIcon,
    this.selectedColor,
    this.unselectedColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.horizontalPadding,
    this.verticalPadding,
    this.spacing,
    this.height,
    this.scrollPadding,
  }) : allowDeselect = false;

  /// Costruttore nullable: permette la deselezione.
  /// Tap su item già selezionato lo deseleziona (restituisce null).
  const AppPillTab.nullable({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.getLabel,
    required this.onSelected,
    this.getIcon,
    this.selectedColor,
    this.unselectedColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.horizontalPadding,
    this.verticalPadding,
    this.spacing,
    this.height,
    this.scrollPadding,
  }) : allowDeselect = true;

  void _handleTap(T item) {
    final isCurrentlySelected = selectedItem == item;
    
    if (allowDeselect && isCurrentlySelected) {
      // Nullable behavior: deseleziona
      (onSelected as ValueChanged<T?>)(null);
    } else if (!isCurrentlySelected) {
      // Seleziona nuovo item (sia standard che nullable)
      onSelected(item);
    }
    // Standard behavior quando già selezionato: non fa nulla
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSpacing = spacing ?? context.spacingSm;
    
    final scrollView = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: scrollPadding,
      child: Row(
        children: items.asMap().entries.map((entry) {
          final item = entry.value;
          final isSelected = selectedItem == item;
          
          return Padding(
            padding: EdgeInsets.only(right: effectiveSpacing),
            child: _RawPillTab(
              label: getLabel(item),
              icon: getIcon?.call(item),
              isSelected: isSelected,
              onTap: () => _handleTap(item),
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              selectedTextColor: selectedTextColor,
              unselectedTextColor: unselectedTextColor,
              horizontalPadding: horizontalPadding,
              verticalPadding: verticalPadding,
            ),
          );
        }).toList(),
      ),
    );
    
    if (height != null) {
      return SizedBox(height: height, child: scrollView);
    }
    
    return scrollView;
  }
}

/// Widget privato che si occupa esclusivamente del rendering di una singola pill.
/// Non contiene logica di business, solo UI e animazioni.
///
/// Principi seguiti:
/// - Single Responsibility: solo rendering
/// - Separation of Concerns: nessuna logica applicativa
/// - Reusability: può essere usato da qualsiasi wrapper
class _RawPillTab extends StatefulWidget {
  final String label;
  final Widget? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final double? horizontalPadding;
  final double? verticalPadding;

  const _RawPillTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.selectedColor,
    this.unselectedColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.horizontalPadding,
    this.verticalPadding,
  });

  @override
  State<_RawPillTab> createState() => _RawPillTabState();
}

class _RawPillTabState extends State<_RawPillTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _handleTapDown(TapDownDetails details) async {
    await _scaleController.forward();
    // Feedback aptico leggero
    HapticFeedback.selectionClick();
  }

  Future<void> _handleTapUp(TapUpDetails details) async {
    await _scaleController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveHorizontalPadding = widget.horizontalPadding ?? context.spacingMd;
    final effectiveVerticalPadding = widget.verticalPadding ?? context.spacingSm;
    
    final backgroundColor = widget.isSelected
        ? (widget.selectedColor ?? colorScheme.primary)
        : (widget.unselectedColor ?? Colors.transparent);
    
    final borderColor = widget.isSelected
        ? (widget.selectedColor ?? colorScheme.primary)
        : colorScheme.outline.withValues(alpha: 0.3);
    
    final textColor = widget.isSelected
        ? (widget.selectedTextColor ?? colorScheme.onPrimary)
        : (widget.unselectedTextColor ?? colorScheme.onSurface.withValues(alpha: 0.8));

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: context.responsiveBorderRadius(20),
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              horizontal: effectiveHorizontalPadding,
              vertical: effectiveVerticalPadding,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: context.responsiveBorderRadius(20),
              border: Border.all(color: borderColor, width: 1),
              // Subtle shadow quando selezionato
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: (widget.selectedColor ?? colorScheme.primary)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  widget.icon!,
                  SizedBox(width: context.spacingXs),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: context.fontSizeXs,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: textColor,
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
