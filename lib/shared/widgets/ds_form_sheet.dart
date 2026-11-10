import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import '../theme/cta_reserved_space.dart';
import '../theme/surface_colors.dart';
import 'ds_button.dart';
import 'ds_glass_band.dart';
import 'ds_sheet_header.dart';

/// Apre un foglio dal basso sul Navigator radice, con le stesse opzioni per
/// tutti i fogli. Con [enableDrag] lo swipe chiude il foglio.
Future<T?> showDsSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool enableDrag = true,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  useSafeArea: true,
  enableDrag: enableDrag,
  backgroundColor: Colors.transparent,
  builder: builder,
);

/// Route comune dei moduli. Lo swipe del modal usa Navigator.pop e aggira
/// PopScope: si chiude con la x, il tasto indietro o il tocco esterno.
Future<T?> showDsFormSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showDsSheet<T>(context, builder: builder, enableDrag: false);

/// Pagina GoRouter che presenta un form nello stesso modal usato dai fogli DS.
class DsFormSheetPage<T> extends Page<T> {
  const DsFormSheetPage({required this.builder, super.key, super.name});

  final WidgetBuilder builder;

  @override
  Route<T> createRoute(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return ModalBottomSheetRoute<T>(
      builder: builder,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context).context,
      ),
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
      settings: this,
    );
  }
}

/// Cornice dei moduli: chiusura in testata, contenuto scorrevole e una CTA.
/// Durante una scrittura impedisce chiusura e modifiche ai campi.
class DsFormSheet extends StatelessWidget {
  const DsFormSheet({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.actionIcon,
    this.onSubmit,
    this.actionKey,
    this.isBusy = false,
    this.actions = const [],
    this.footer,
    this.padding,
    this.expand = false,
  });

  final String title;
  final Widget child;
  final String? actionLabel;

  /// Icona della CTA, prima dell'etichetta.
  final IconData? actionIcon;
  final VoidCallback? onSubmit;
  final Key? actionKey;
  final bool isBusy;
  final List<Widget> actions;

  /// Piè fisso al posto della CTA singola (per due bottoni o un avviso). Ha la
  /// precedenza su [actionLabel].
  final Widget? footer;

  /// Padding del contenuto. `null` vale `EdgeInsets.all(context.spacingMd)`.
  final EdgeInsetsGeometry? padding;

  /// Il foglio prende tutta l'altezza massima e il contenuto riempie lo spazio
  /// tra testata e CTA, senza scroll esterno né padding: per i contenuti che
  /// scorrono da soli, come il calendario.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        AppConstants.sheetMaxHeightFactor *
        (MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom);

    final content = AbsorbPointer(absorbing: isBusy, child: child);
    final footerContent =
        footer ??
        (actionLabel == null
            ? null
            : Padding(
                padding: EdgeInsets.fromLTRB(
                  context.spacingMd,
                  DsGlassBand.topGap(context),
                  context.spacingMd,
                  context.spacingMd,
                ),
                child: DsButton(
                  key: actionKey,
                  label: actionLabel!,
                  icon: actionIcon,
                  onPressed: onSubmit,
                  isLoading: isBusy,
                  expand: true,
                ),
              ));
    final body = _SheetBody(
      expand: expand,
      padding: padding ?? EdgeInsets.all(context.spacingMd),
      footer: footerContent,
      child: content,
    );

    final frame = Container(
      decoration: BoxDecoration(
        // Superficie 1, staccata dalla pagina: dentro, card e campi sono la 2.
        color: context.raisedSurface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.modalBorderRadius),
        ),
      ),
      child: SheetSurfaceScope(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AbsorbPointer(
                absorbing: isBusy,
                child: DsSheetHeader(
                  title: title,
                  actions: actions,
                  onClose: () => Navigator.pop(context),
                ),
              ),
              body,
            ],
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !isBusy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: expand
            ? SizedBox(height: maxHeight, child: frame)
            : ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: frame,
              ),
      ),
    );
  }
}

/// Contenuto del foglio con il piè sopra, sulla fascia di vetro come i
/// bottoni in fondo alle pagine: il contenuto scorre sotto il piè, sfocato,
/// e in fondo ha lo spazio per salire sopra di lui.
class _SheetBody extends StatefulWidget {
  const _SheetBody({
    required this.expand,
    required this.padding,
    required this.footer,
    required this.child,
  });

  final bool expand;
  final EdgeInsetsGeometry padding;
  final Widget? footer;
  final Widget child;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  /// Altezza del piè, misurata dopo il layout.
  double _footerHeight = 0;
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _footerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final footer = widget.footer;
    return widget.expand
        ? Expanded(child: _buildBody(context, footer, double.infinity))
        : Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  _buildBody(context, footer, constraints.maxHeight),
            ),
          );
  }

  Widget _buildBody(BuildContext context, Widget? footer, double maxHeight) {
    final hasRoomForContent =
        maxHeight.isFinite &&
        maxHeight - _footerHeight >= kMinInteractiveDimension;
    final footerInScroll =
        footer != null && !widget.expand && !hasRoomForContent;
    final reserved = footer == null || footerInScroll ? 0.0 : _footerHeight;
    final child = KeyedSubtree(key: _contentKey, child: widget.child);

    Widget measuredFooter() => KeyedSubtree(
      key: _footerKey,
      child: _MeasureSize(
        onChange: (size) {
          if (mounted && size.height != _footerHeight) {
            setState(() => _footerHeight = size.height);
          }
        },
        child: DsGlassBand(child: footer!),
      ),
    );

    // Con un piè fisso, il contenuto scorre e riserva la sua altezza. Quando
    // non resta neppure un controllo interattivo di spazio libero, contenuto e
    // piè condividono invece lo stesso scroll.
    final content = CtaReservedSpaceScope(
      height: reserved,
      child: widget.expand
          ? child
          : footerInScroll
          ? SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(padding: widget.padding, child: child),
                  measuredFooter(),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: widget.padding.add(EdgeInsets.only(bottom: reserved)),
              child: child,
            ),
    );

    final stack = footer == null || footerInScroll
        ? content
        : Stack(
            fit: widget.expand ? StackFit.expand : StackFit.loose,
            children: [
              content,
              Positioned(left: 0, right: 0, bottom: 0, child: measuredFooter()),
            ],
          );

    return stack;
  }
}

/// Riporta la misura del figlio dopo ogni layout in cui cambia.
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _last) return;
    _last = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(measured));
  }
}
