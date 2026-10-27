import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/app_spacing.dart';
import 'postcard_parts.dart';

/// Pila di cartoline da sfogliare orizzontalmente.
///
/// La cartolina in cima è dritta a riposo; sotto si intravedono al massimo due
/// fogli di carta vuoti. Trascinando verso sinistra la cartolina esce e quella
/// sotto sale al suo posto; verso destra è il movimento contrario: la
/// precedente rientra dall'alto e quella in cima scende nella pila. Il
/// rilascio avanza o torna indietro oltre una soglia di spostamento o di
/// velocità, altrimenti la cartolina torna al centro.
///
/// Richiede un'altezza vincolata dal genitore: le cartoline occupano lo spazio
/// sopra l'indicatore dei puntini.
class PostcardPile extends StatefulWidget {
  final int itemCount;

  /// Cartolina con cui la pila si apre. Vale solo alla creazione dello stato:
  /// se è fuori intervallo la pila parte dalla prima.
  final int initialIndex;

  /// Costruisce la cartolina in posizione [index]. Chiamato solo per la
  /// cartolina in cima, e per quella che sale durante lo scorrimento.
  final IndexedWidgetBuilder itemBuilder;

  /// Etichetta accessibile della cartolina in cima.
  final String Function(int index) semanticLabel;

  const PostcardPile({
    super.key,
    required this.itemCount,
    this.initialIndex = 0,
    required this.itemBuilder,
    required this.semanticLabel,
  });

  @override
  State<PostcardPile> createState() => _PostcardPileState();
}

class _PostcardPileState extends State<PostcardPile>
    with SingleTickerProviderStateMixin {
  static const Duration _animationDuration = Duration(milliseconds: 250);

  /// Frazione della larghezza oltre la quale lo spostamento conta come swipe.
  static const double _commitFraction = 0.25;

  /// Velocità (px/s) oltre la quale un rilascio conta come swipe.
  static const double _flingVelocity = 700;

  /// Quanto pesa il trascinamento oltre il primo o l'ultimo elemento.
  static const double _edgeResistance = 0.3;

  /// Inclinazione massima (rad) della cartolina mentre la trascini.
  static const double _maxDragTilt = 0.08;

  /// Inclinazione (rad) dei fogli a ogni livello sotto la cartolina in cima.
  static const List<double> _levelTilts = [0, 0.045, -0.06];

  /// Fogli visibili sotto la cartolina in cima, e spazio riservato sotto.
  static const int _visibleLevels = 2;

  late final AnimationController _controller;

  /// Indice della cartolina in cima.
  int _index = 0;

  /// Spostamento orizzontale della cartolina in cima (trascinamento o
  /// animazione).
  double _dx = 0;

  /// Larghezza della pila, misurata in [build].
  double _width = 0;

  double _from = 0;
  double _to = 0;

  /// Indice da applicare a fine animazione, se il gesto è stato confermato.
  int? _commitTo;

  /// Vero se il puntatore è stato interrotto dal sistema (cancel): il rilascio
  /// che ne segue non deve confermare lo scorrimento.
  bool _interrupted = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIndex;
    _index = initial >= 0 && initial < widget.itemCount ? initial : 0;
    _controller = AnimationController(vsync: this, duration: _animationDuration)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant PostcardPile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pending = _commitTo;
    if (_index >= widget.itemCount ||
        (pending != null && pending >= widget.itemCount)) {
      _controller.stop();
      _commitTo = null;
      _index = 0;
      _dx = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasNext => _index < widget.itemCount - 1;
  bool get _hasPrevious => _index > 0;

  void _onTick() {
    setState(() {
      _dx = _from + (_to - _from) * Curves.easeOut.transform(_controller.value);
    });
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final target = _commitTo;
    _commitTo = null;
    if (target == null) return;
    setState(() {
      _index = target;
      _dx = 0;
    });
  }

  void _settle(double target, {int? commitTo}) {
    _from = _dx;
    _to = target;
    _commitTo = commitTo;
    _controller.forward(from: 0);
  }

  void _onDragStart(DragStartDetails details) {
    _controller.stop();
    _commitTo = null;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    var delta = details.delta.dx;
    final next = _dx + delta;
    final blocked = next < 0 ? !_hasNext : (next > 0 && !_hasPrevious);
    if (blocked) delta *= _edgeResistance;
    setState(() => _dx += delta);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_interrupted) {
      _settle(0);
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final threshold = _width * _commitFraction;
    final swipedNext =
        _dx < 0 && (-_dx > threshold || -velocity > _flingVelocity);
    final swipedPrevious =
        _dx > 0 && (_dx > threshold || velocity > _flingVelocity);

    if (swipedNext && _hasNext) {
      _settle(-_width, commitTo: _index + 1);
    } else if (swipedPrevious && _hasPrevious) {
      _settle(_width, commitTo: _index - 1);
    } else {
      _settle(0);
    }
  }

  /// Inclinazione proporzionale alla posizione orizzontale, con tetto a
  /// [_maxDragTilt]. A riposo (x = 0) vale zero.
  double _tiltFor(double x) {
    if (_width <= 0) return 0;
    return (x / _width).clamp(-1.0, 1.0).toDouble() * _maxDragTilt;
  }

  /// Inclinazione di un foglio al livello [level] (anche frazionario, durante
  /// lo scorrimento), interpolata tra i valori di [_levelTilts].
  static double _levelTilt(double level) {
    final lower = math.min(math.max(level.floor(), 0), _levelTilts.length - 2);
    return _levelTilts[lower] +
        (_levelTilts[lower + 1] - _levelTilts[lower]) * (level - lower);
  }

  /// Un livello della pila. [layerKey] lo lega alla cartolina di cui fa parte,
  /// così scorrendo un livello resta lo stesso elemento e non si ricostruisce.
  static Widget _pose({
    Key? key,
    required Key layerKey,
    required double dx,
    required double dy,
    required double angle,
    required Widget child,
  }) {
    return Positioned.fill(
      key: layerKey,
      child: Transform(
        key: key,
        alignment: Alignment.center,
        transform: Matrix4.translationValues(dx, dy, 0)..rotateZ(angle),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.itemCount;
    if (count == 0) return const SizedBox.shrink();

    final index = _index;
    final spacing = context.spacingSm;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _width = constraints.maxWidth;
              return Listener(
                onPointerDown: (_) => _interrupted = false,
                onPointerCancel: (_) => _interrupted = true,
                child: GestureDetector(
                  key: const Key('postcard_pile'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: Semantics(
                    container: true,
                    label: widget.semanticLabel(index),
                    customSemanticsActions: {
                      if (_hasNext)
                        CustomSemanticsAction(
                          label: 'trips.pile.next'.tr(),
                        ): () =>
                            _settle(-_width, commitTo: index + 1),
                      if (_hasPrevious)
                        CustomSemanticsAction(
                          label: 'trips.pile.previous'.tr(),
                        ): () =>
                            _settle(_width, commitTo: index - 1),
                    },
                    child: _buildPile(context, index, spacing),
                  ),
                ),
              );
            },
          ),
        ),
        if (count > 1) ...[
          SizedBox(height: context.spacingMd),
          _PileDots(
            key: const Key('postcard_pile_dots'),
            count: count,
            index: index,
          ),
        ],
      ],
    );
  }

  /// Costruisce la cartolina di [index] con una chiave propria: così lo stato
  /// di un elemento non passa a quello successivo dopo uno scorrimento.
  Widget _item(BuildContext context, int index) {
    return KeyedSubtree(
      key: ValueKey(index),
      child: widget.itemBuilder(context, index),
    );
  }

  Widget _buildPile(BuildContext context, int index, double spacing) {
    final count = widget.itemCount;
    // Quanto la cartolina successiva è già salita verso la cima (0..1).
    final forward = _hasNext && _dx < 0 && _width > 0
        ? (-_dx / _width).clamp(0.0, 1.0).toDouble()
        : 0.0;
    // Quanto la precedente è già rientrata (0..1): è il movimento contrario,
    // e la cartolina in cima scende di un livello mentre rientra.
    final backward = _hasPrevious && _dx > 0 && _width > 0
        ? (_dx / _width).clamp(0.0, 1.0).toDouble()
        : 0.0;

    final layers = <Widget>[
      if (index + 2 < count)
        _pose(
          layerKey: ValueKey('layer-${index + 2}'),
          dx: 0,
          dy: spacing * (2 - forward + backward),
          angle: _levelTilt(2 - forward + backward),
          // Tornando indietro il foglio più in basso esce dalla pila.
          child: Opacity(opacity: 1 - backward, child: const PostcardPaper()),
        ),
      if (index + 1 < count)
        _pose(
          layerKey: ValueKey('layer-${index + 1}'),
          dx: 0,
          dy: spacing * (1 - forward + backward),
          angle: _levelTilt(1 - forward + backward),
          child: forward > 0
              ? _item(context, index + 1)
              : const PostcardPaper(),
        ),
      // La cartolina in cima: segue il dito, oppure scende nella pila mentre
      // rientra la precedente.
      _pose(
        key: const Key('postcard_pile_top'),
        layerKey: ValueKey('layer-$index'),
        dx: backward > 0 ? 0 : _dx,
        dy: spacing * backward,
        angle: backward > 0 ? _levelTilt(backward) : _tiltFor(_dx),
        child: _item(context, index),
      ),
      if (backward > 0)
        _pose(
          layerKey: ValueKey('layer-${index - 1}'),
          dx: _dx - _width,
          dy: 0,
          angle: _tiltFor(_dx - _width),
          child: _item(context, index - 1),
        ),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: spacing * _visibleLevels),
      child: Stack(clipBehavior: Clip.none, children: layers),
    );
  }
}

/// Puntini di posizione con il contatore "2 di 4". Neutri: il puntino attivo
/// è più largo.
class _PileDots extends StatelessWidget {
  final int count;
  final int index;

  const _PileDots({super.key, required this.count, required this.index});

  static const Duration _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var k = 0; k < count; k++)
          AnimatedContainer(
            duration: _duration,
            margin: EdgeInsets.symmetric(horizontal: context.spacingXxs),
            width: k == index ? context.spacingMd : context.spacingSm,
            height: context.spacingSm,
            decoration: BoxDecoration(
              color: k == index ? cs.onSurface : cs.outlineVariant,
              borderRadius: BorderRadius.circular(
                AppConstants.smallBorderRadius,
              ),
            ),
          ),
        SizedBox(width: context.spacingSm),
        Text(
          'trips.pile.position'.tr(args: ['${index + 1}', '$count']),
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
